import * as libubus from 'ubus';
import * as uclient from 'uclient';
import * as uloop from 'uloop';
import * as fs from 'fs';
import * as digest from 'digest';
import * as nl80211 from 'nl80211';

import * as fnsh_wifi_data from 'fnsh.wifi.data';
import * as fnsh_wifi_tlv from 'fnsh.wifi.tlv';
import * as beacon from 'fnsh.wifi.beacon';


let update_interval = 5 * 1000; // 5 seconds
let ubus = libubus.connect();

let instance_hash = digest.sha1(fs.readfile('/dev/urandom', 16));
let local_clients = {};
let submission_buffer = [];

uloop.init();

function get_node_info() {
	let node_id = trim(fs.readfile('/lib/gluon/core/sysconfig/primary_mac'));
	let wifi_macs = [];

	let interfaces = nl80211.request(nl80211.const.NL80211_CMD_GET_INTERFACE, nl80211.const.NLM_F_DUMP, {});
	for (let iface in interfaces) {
		if (iface.ifname == "client0" || iface.ifname == "owe0" || iface.ifname == "client1" || iface.ifname == "owe1")
			push(wifi_macs, iface.mac);
	}

	return { node_id: node_id, wifi_macs: wifi_macs };
}

function anonymize_mac(mac) {
	let result_hash = digest.sha1(instance_hash + mac);
	let tmp_mac_str = "";

	for (let i = 0; i < 12; i += 2) {
		let num_octet = hex(substr(result_hash, i, 2));
		if (i == 0) {
			num_octet = num_octet | 0x02; // LA
			num_octet = num_octet & 0xFE; // Unicast
		}
		tmp_mac_str += fnsh_wifi_data.hexencode_octet(num_octet);
		if (i < 10) {
			tmp_mac_str += ":";
		}
	}

	return tmp_mac_str;
}

function client_list_get_or_create(mac) {
	if (!(mac in local_clients)) {
		local_clients[mac] = {
			'anonymized_mac': anonymize_mac(mac),
		};
	}
	return local_clients[mac];
}

function http_post(url, data) {
	uc = uclient.new(url, null, {
		header_done: (cb) => {
			warn(sprintf("Headers: %.J\nStatus: %.J\n", uc.get_headers(), uc.status()));
		},
		error: (cb, code) => {
			warn(`Error: ${code}\n`);
			uloop.end();
		}
	});

	if (!uc.ssl_init({ verify: false })) {
		warn(`Failed to initialize SSL\n`);
		exit(1);
	}

	if (!uc.connect()) {
		warn(`Failed to connect\n`);
		exit(1);
	}
	if (!uc.request("POST", {
		post_data: sprintf("%J", data)
	})) {
		warn(`Failed to send request\n`);
		exit(1);
	}
}

function update_timer_run() {
	print(`Updating submission buffer with ${length(submission_buffer)} entries\n`);
	if (length(submission_buffer) <= 0) {
		update_timer.set(update_interval);
		return;
	}

	/* Upload submission buffer to the server */
	let submission_request_object = {
		node_info: get_node_info(),
		reports: submission_buffer
	};

	print(submission_request_object, '\n');
	http_post("https://beacons.as62028.de/v1/submission", submission_request_object);

	/* Delete submission buffer after uploading */
	submission_buffer = [];
	update_timer.set(update_interval);
}

function create_submission_object(client_report) {
	/* Anonymize MAC */
	let first_fragment = client_report.report_fragments[0];
	let client_mac = first_fragment.meta.client_mac;
	let client = client_list_get_or_create(client_mac);

	let submission_object = {
		meta: {
			receive_timestamp: first_fragment.meta.receive_timestamp,
			client_mac: client.anonymized_mac,
			bssid: first_fragment.content.fixed.bssid,
		},
		fixed: first_fragment.content.fixed,
		beacon: {
			parsed: {

			},
		},
	};

	/* Parse beacon data */
	let beacon_octet_array = fnsh_wifi_data.octet_array_from_string(hexdec(client_report.parsed_beacon));
	for (let i = 0; i < 12; i++)
			shift(beacon_octet_array);
	let beacon_data = fnsh_wifi_tlv.tlv_list_from_octet_array(beacon_octet_array);

	/* Parse QBSS Load, SSID and OWE Transition SSID */
	let qbss_load = beacon.beacon_elements_parse_qbss_load(beacon_data);
	if (qbss_load)
		submission_object.beacon.parsed.qbss_load = qbss_load;
	
	let ssid = beacon.beacon_elements_parse_ssid(beacon_data);
	if (ssid)
		submission_object.beacon.parsed.ssid = ssid;

	let owe_transition_ssid = beacon.beacon_elements_parse_owe_transition_ssid(beacon_data);
	if (owe_transition_ssid) {
		let anonymized_mac = anonymize_mac(owe_transition_ssid.bssid);
		owe_transition_ssid.bssid = anonymized_mac;
		submission_object.beacon.parsed.owe_transition_ssid = owe_transition_ssid;
	}

	/* Purge first elements from submission buffer if it exceeds 50 entries */
	while (length(submission_buffer) > 50)
		shift(submission_buffer);

	if (ssid == "darmstadt.freifunk.net")
		push(submission_buffer, submission_object);
}

function submission_buffer_add(ubus_data) {
	let submission_obj = create_submission_object(ubus_data.report);
}

const listener = ubus.listener("beacon-report-collector.*", (pattern, data) => {
	submission_buffer_add(data);
});

/* Schedule update timer */
update_timer = uloop.timer(update_interval, update_timer_run);

/* Run the main loop */
uloop.run();