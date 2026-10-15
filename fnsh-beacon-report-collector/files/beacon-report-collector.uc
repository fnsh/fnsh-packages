#!/usr/bin/env ucode

'use strict';

import * as libubus from 'ubus';
import * as uloop from 'uloop';
import * as fnsh_wifi_data from 'fnsh.wifi.data';
import * as fnsh_wifi_beacon_report from 'fnsh.wifi.beacon-report';

uloop.init();

let hostapd_instances = {};
let ubus = libubus.connect();
let update_timer;
let all_clients = {};

let aggregation_cache = fnsh_wifi_beacon_report.aggregation_cache_new();
let config = {
	update_interval: 5,
	request_interval: 3 * 60, // 3 minutes
	report_retention: 10 * 60, // 10 minutes
	client_retention: 2 * 60, // 2 minutes
	max_reports_per_client: 5, // Maximum number of reports to keep per client
};

let statistics = {
	global: {
		request_counter: 0,
		report_counter: 0,
		aggregated_reports: 0,
	},
	errors: {
		missing_report: 0,
		beacon_report_parsing: 0,
		report_aggregation: 0,
	}
};

let state = {
	aggregation_pending: false,
};

function client_get(client_mac) {
	if (!(client_mac in all_clients))
		return null;
	return all_clients[client_mac];
}

function client_get_or_add(client_mac, ifname) {
	let client = client_get(client_mac);
	if (client != null)
		return client;

	all_clients[client_mac] = {
		mac: client_mac,
		instance: hostapd_instances[ifname],
		reports: {},
		statistics: {
			last_request: 0,
			num_requests: 0,
			last_report: 0,
			num_reports: 0,
		}
	};

	return all_clients[client_mac];
}

function client_cleanup() {
	for (let client_mac in all_clients) {
		let client = all_clients[client_mac];
		if (clock(true)[0] - client['last_seen'] > config.client_retention) {
			delete all_clients[client_mac];
		}
	}
}

function hostapd_ubus_subscriber_remove_cb() {
	/* Handled by object removal */
}

function hostapd_ubus_subscriber_notify_cb(ubus_obj_path, ubus_ifname, obj) {
	// This function is called when a hostapd instance sends a notification
	if (obj.type != 'beacon-report')
		return;

	if (!('report' in obj.data)) {
		statistics.errors.missing_report++;
		return;
	}

	let report_octet_array = fnsh_wifi_data.octet_array_from_base64(obj.data.report);
	fnsh_wifi_beacon_report.aggregation_cache_report_add(aggregation_cache, obj.data.address, report_octet_array, hostapd_instances[ubus_ifname].bssid, clock(true)[0]);

	all_clients[obj.data.address]['statistics'].last_report = clock(true)[0];
	all_clients[obj.data.address]['statistics'].num_reports++;
	statistics.global.report_counter++;
	state.aggregation_pending = true;
}

function hostapd_update_clients(ifname) {
	let path = hostapd_instances[ifname].path;
	let clients = ubus.call(path, 'get_clients');

	/* Update clients */
	for (let client_mac in clients.clients) {
		let client_info = clients.clients[client_mac];
		let client_obj = client_get_or_add(client_mac, ifname);

		client_obj['last_seen'] = clock(true)[0];
		client_obj['beacon_reports'] = {
			passive: !!(client_info.rrm[0] & 16),
			active: !!(client_info.rrm[0] & 32),
			table: !!(client_info.rrm[0] & 64)
		};
	}

	/* Delete stale clients */
	client_cleanup();
}

function hostapd_update(path, ifname) {
	if (!(ifname in hostapd_instances)) {
		const request_object_path = path;
		const request_object_ifname = ifname;
		hostapd_instances[ifname] = {
			ifname: ifname,
			path: path,
			subscriber: ubus.subscriber((obj) => {
				hostapd_ubus_subscriber_notify_cb(request_object_path, request_object_ifname, obj);
			}, hostapd_ubus_subscriber_remove_cb),
			clients: {},
		};

		hostapd_instances[ifname].subscriber.subscribe(path);
	}

	/* Update Status */
	let status = ubus.call(path, 'get_status');
	hostapd_instances[ifname].bssid = status.bssid;

	/* Update clients */
	hostapd_update_clients(ifname);
}


function hostapd_add(path, obj) {
	let ifname = obj[1];

	/* Enable neighbor reports from AP and beacon reports from STA */
	ubus.call(path, 'bss_mgmt_enable', { 'neighbor_report': true, 'beacon_report': true });

	/* Update information from hostapd */
	hostapd_update(path, ifname);
	
	/* Reset list of neighbor reports */
	ubus.call(path, 'rrm_nr_set', { list: [] });
}

function hostapd_remove(path, obj) {
	let ifname = obj[1];

	/* Remove the subscriber */
	if (ifname in hostapd_instances) {
		hostapd_instances[ifname].subscriber.unsubscribe(path);
		hostapd_instances[ifname].subscriber.remove();
		hostapd_instances[ifname].subscriber = null;
	}

	delete hostapd_instances[ifname];
}

function hostapd_detect() {
	let list = ubus.list();
	for (let k, path in list) {
		let object = split(path, '.');
		if (object[0] != 'hostapd' || !object[1]) {
			continue;
		}

		hostapd_add(path, object);
	}
}

function ubus_listener_event(event, payload) {
	let path = payload.path;
	let object = split(path, '.');
	if (object[0] == 'hostapd' && object[1]) {
		if (event == 'ubus.object.add')
			hostapd_add(path, object);
		else
			hostapd_remove(path, object);
	}
}

function client_reports_add(client_mac, bssid, aggregated_data) {
	let client = client_get_or_add(client_mac);

	if (!(bssid in client.reports)) {
		client.reports[bssid] = [];
	}
	push(client.reports[bssid], aggregated_data);
}

function client_reports_cleanup(client_mac) {
	let client = client_get(client_mac);
	if (!client)
		return;

	let new_bssids = {};

	for (let bssid_key in client.reports) {
		let new_bss_reports = [];
		let bssid_reports = client.reports[bssid_key];
		for (let report in bssid_reports) {
			let first_fragment = report.report_fragments[0];
			if (first_fragment == null)
				continue;
			if (first_fragment.meta.receive_timestamp + config.report_retention <= clock(true)[0]) {
				print('Removing expired report for client ' + client_mac + ' and bssid ' + bssid_key + '\n');
				continue;
			}
			push(new_bss_reports, report);
		}
		if (length(new_bss_reports))
			new_bssids[bssid_key] = new_bss_reports;
	}
	client.reports = new_bssids;
}

function client_report_convert(bssid_report) {
	for (let bssid_report_fragment in bssid_report.report_fragments) {
		let report_age = clock(true)[0] - bssid_report_fragment.meta.receive_timestamp;
		bssid_report_fragment.meta.receive_timestamp = time() - report_age;
	}
}

function update_timer_run() {
	/* Update all hostapd instances */
	for (let ifname, instance in hostapd_instances) {
		hostapd_update(instance.path, ifname);
	}

	/* Update pending aggregations */
	if (state.aggregation_pending) {
		state.aggregation_pending = false;

		let aggregated_results = fnsh_wifi_beacon_report.aggregation_cache_aggregate(aggregation_cache);

		for (let client_mac in aggregated_results) {
			let client_data = aggregated_results[client_mac];
			for (let bssid in client_data.reported_bss) {
				let aggregated_data = client_data.reported_bss[bssid];
				for (let bssid_report in aggregated_data) {
					client_reports_add(client_mac, bssid, bssid_report);
					let deepcloned_report = fnsh_wifi_data.object_deepclone(bssid_report);
					client_report_convert(deepcloned_report);
					ubus.event('beacon-report-collector.beacon.received', {
						report: deepcloned_report,
					});
				}
			}
		}
	}

	/* Query devices for neighbor reports */
	for (let client_mac in all_clients) {
		let client = all_clients[client_mac];

		/* Client capable ? */
		if (!client.beacon_reports.table)
			continue;

		/* Check if update due */
		if (client.statistics.last_request + config.request_interval >= clock(true)[0] && client.statistics.num_requests > 0)
			continue;

		/* Cleanup reports which timed out */
		client_reports_cleanup(client_mac);

		ubus.call(client.instance.path, 'rrm_beacon_req', {
			addr: client_mac,
			mode: 2,
			op_class: 0,
			channel: 0,
			duration: 0,
			reporting_detail: 2,
		});
		client.statistics.last_request = clock(true)[0];
		client.statistics.num_requests++;
		statistics.global.request_counter++;
	}

	update_timer.set(config.update_interval * 1000);
	gc();
}

ubus.listener('ubus.object.add', ubus_listener_event);
ubus.listener('ubus.object.remove', ubus_listener_event);

/* First update needs to be done manually */
hostapd_detect();

/* Own ubus methods */
let ubus_methods = {
	'status': {
		call: function(request) {
			return {
				'status': 'ok',
				'instances': hostapd_instances
			};
		},
		args : {}
	},
	'statistics': {
		call: function(request) {
			return statistics;
		},
		args: {}
	},
	'reports': {
		call: function(request) {
			let reps = {};

			for (let client_mac in all_clients) {
				let client = all_clients[client_mac];
				if (length(client.reports) > 0) {
					let bssids = {};
					for (let bssid in client.reports) {
						let bssid_reports = fnsh_wifi_data.object_deepclone(client.reports[bssid]);
						for (let bssid_report in bssid_reports) {
							client_report_convert(bssid_report);
						}
						bssids[bssid] = bssid_reports;
					}
					reps[client_mac] = bssids;
				}
			}
			return reps;
		},
		args: {}
	},
};
ubus.publish('beacon-report-collector', ubus_methods);

/* Schedule update timer */
update_timer = uloop.timer(config.update_interval * 1000, update_timer_run);

/* Run the main loop */
uloop.run();