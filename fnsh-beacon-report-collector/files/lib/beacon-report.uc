import * as fnsh_wifi_data from 'fnsh.wifi.data';
import * as fnsh_wifi_tlv from 'fnsh.wifi.tlv';

let BEACON_REPORT_FIXED_LENGTH = 26;

export function frame_has_subelements(octet_array) {
	return length(octet_array) > BEACON_REPORT_FIXED_LENGTH;
};

function frame_subelements_get_octet_array(octet_array) {
	let cloned_array = fnsh_wifi_data.octet_array_clone(octet_array);
	splice(cloned_array, 0, BEACON_REPORT_FIXED_LENGTH);
	return cloned_array;
}

function frame_subelements_get_parsed(octet_array) {
	if (!frame_has_subelements(octet_array)) {
		return nil;
	}
	let subelements_octet_array = frame_subelements_get_octet_array(octet_array);
	let tlv_list = fnsh_wifi_tlv.tlv_list_from_octet_array(subelements_octet_array);

	let return_object = {};
	for (let i = 0; i < length(tlv_list); i++) {
		let tlv = tlv_list[i];
		if (tlv.type == 1) {
			return_object['frame_body'] = tlv.value;
		} else if (tlv.type == 2 && tlv.length == 2) {
			return_object['fragment_id'] = {
				report_id: tlv.value[0],
				fragment_id: tlv.value[1] & 127,
				more_fragments: (tlv.value[1] & 128) != 0,
			};
		}
	}

	return return_object;
}

function frame_fixed_get_parsed(octet_array) {
	if (length(octet_array) < BEACON_REPORT_FIXED_LENGTH) {
		return null;
	}

	let fixed = {
		'operating_class': fnsh_wifi_data.octet_array_parse_uint8(octet_array, 0),
		'channel': fnsh_wifi_data.octet_array_parse_uint8(octet_array, 1),
		'actual_measurement_start_time': fnsh_wifi_data.octet_array_parse_uint64(octet_array, 2),
		'measurement_duration': fnsh_wifi_data.octet_array_parse_uint16(octet_array, 10),
		'reported_frame_information': fnsh_wifi_data.octet_array_parse_uint8(octet_array, 12),
		'rcpi': fnsh_wifi_data.octet_array_parse_uint8(octet_array, 13),
		'rsni': fnsh_wifi_data.octet_array_parse_uint8(octet_array, 14),
		'bssid': fnsh_wifi_data.octet_array_parse_mac(octet_array, 15),
		'antenna_id': fnsh_wifi_data.octet_array_parse_uint8(octet_array, 21),
		'parent_tsf': fnsh_wifi_data.octet_array_parse_uint32(octet_array, 22),
	};

	return fixed;
}

export function aggregation_cache_new()	{
	return {
		"clients": {}
	};
};

function aggregation_cache_client_get_or_add(cache, client_mac) {
	if (!(client_mac in cache.clients)) {
		cache.clients[client_mac] = {
			reported_bss: {}
		};
	}
	return cache.clients[client_mac];
}

export function aggregation_cache_report_add(cache, client_mac, report_frame_octet_array, received_bss, received_time) {
	let client = aggregation_cache_client_get_or_add(cache, client_mac);
	let entry = {
		'meta': {
			'connected_bss': received_bss,
			'client_mac': client_mac,
			'receive_timestamp': received_time
		},
		'content': {
			'fixed': frame_fixed_get_parsed(report_frame_octet_array),
			'subelements': frame_subelements_get_parsed(report_frame_octet_array),
		},
		'frame': report_frame_octet_array
	};

	// ToDo: throw error here and handle in caller
	if (!entry.content.subelements || entry.content.subelements['frame_body'] == null || entry.content.subelements['fragment_id'] == null)
		return;

	// Create or get the BSSID
	let report_bssid = entry.content.fixed.bssid;
	if (!(report_bssid in client.reported_bss)) {
		client.reported_bss[report_bssid] = {
			'created': clock(true),
			'reports': {}
		};
	}

	// Create or get report id
	let report_id_key = '' + entry.content.subelements['fragment_id'].report_id;
	if (!(report_id_key in client.reported_bss[report_bssid].reports)) {
		client.reported_bss[report_bssid].reports[report_id_key] = {
			'created': clock(true),
			'fragments': []
		};
	}

	push(client.reported_bss[report_bssid].reports[report_id_key].fragments, entry);
};

function aggregation_cache_aggregate_fragment_sorting_func(a, b) {
	return (a.content.subelements.fragment_id.fragment_id) - (b.content.subelements.fragment_id.fragment_id);
}

function aggregation_cache_aggregate_client_bss_can_aggregate(sorted_fragments) {
	let current_fragment_id = 0;
	for (let report_fragment in sorted_fragments) {
		/* Validate each fragment here if needed */
		let report_fragment_id = report_fragment.content.subelements.fragment_id.fragment_id;
		let more_fragments = report_fragment.content.subelements.fragment_id.more_fragments;

		/* This might fail in case more-fragments is set and we still receive fragments out of order */
		if (report_fragment_id != current_fragment_id) {
			assert(false, 'Unexpected Fragment ID. Expected ' + current_fragment_id + ' but got ' + report_fragment_id + '\n');
		}

		/* If this is the last fragment, more fragments shall not be set */
		if (length(sorted_fragments) > current_fragment_id + 1 && !more_fragments) {
			assert(false, 'Unexpected fragment after the last fragment');
		} else if (length(sorted_fragments) == current_fragment_id + 1 && more_fragments) {
			assert(false, 'More fragments flag set on the last fragment');
		}

		current_fragment_id++;
	}
}

function aggregation_cache_cleanup_client(cache, client_mac) {
	let client = cache.clients[client_mac];
	if (!client) return;

	for (let bssid in client.reported_bss) {
		for (let report_id_key in client.reported_bss[bssid].reports) {
			let report = client.reported_bss[bssid].reports[report_id_key];
			if (report.created + 15 <= clock(true)) {
				delete client.reported_bss[bssid].reports[report_id_key];
			}
		}

		if (length(client.reported_bss[bssid].reports) == 0) {
			delete client.reported_bss[bssid];
		}
	}

	if (length(client.reported_bss) == 0) {
		delete cache.clients[client_mac];
	}
}

function aggregation_cache_aggregate_client_bss(cache, client_mac, bssid) {
	let client = cache.clients[client_mac];
	if (!client || !(bssid in client.reported_bss))
		return null;

	let concatenated_reports = [];
	for (let report_id_key in client.reported_bss[bssid].reports) {
		let fragments = client.reported_bss[bssid].reports[report_id_key].fragments;
		let sorted_fragments = sort(fragments, aggregation_cache_aggregate_fragment_sorting_func);

		// First check if aggregation is possible
		try {
			aggregation_cache_aggregate_client_bss_can_aggregate(sorted_fragments);
		} catch (e) {
			continue;
		}
		
		// Aggregate the Subelements from fragments for this report ID here
		try {
			let fixed_elements = [];
			let variable_elements = [];
			for (let fragment in sorted_fragments) {
				// Each frame contains fixed + Subset of variable
				fixed_elements = splice(fnsh_wifi_data.octet_array_clone(fragment.content.subelements.frame_body), 12);

				// Variable part always contains full TLVs. Can parse them here and concat to variable_elements
				let variable_tlv_in_beacon = splice(fnsh_wifi_data.octet_array_clone(fragment.content.subelements.frame_body), 0, 12);
				for (let elem in variable_tlv_in_beacon) {
					push(variable_elements, elem);
				}

				// Convert frame to hexstring
				let frame_hex = fnsh_wifi_data.octet_array_to_hex(fragment.frame);
				fragment.frame = frame_hex;

				// For output, delete frame-body (Can be reconstructed)
				delete fragment.content.subelements.frame_body;
			}

			let return_elem = {
				'report_fragments': sorted_fragments,
				'parsed_beacon': fnsh_wifi_data.octet_array_to_hex(fixed_elements) + fnsh_wifi_data.octet_array_to_hex(variable_elements)
			};
			push(concatenated_reports, return_elem);
		} catch (e) {
			print(e.msg, e.stack, '\n');
		}
		delete client.reported_bss[bssid].reports[report_id_key];
	}

	/* ToDo: Shall we do full cleanup here? */
	aggregation_cache_cleanup_client(cache, client_mac);

	if (length(concatenated_reports) == 0)
		return null;

	return concatenated_reports;
}

export function aggregation_cache_aggregate_client(cache, client_mac) {
	let client = cache.clients[client_mac];
	if (!client) return null;

	let aggregated = {
		'reported_bss': {}
	};

	for (let bssid in client.reported_bss) {
		let concatenated_reports = aggregation_cache_aggregate_client_bss(cache, client_mac, bssid);
		if (concatenated_reports == null || length(concatenated_reports) == 0)
			continue;
		aggregated.reported_bss[bssid] = concatenated_reports;
	}

	if (length(aggregated.reported_bss) == 0)
		return null;
	return aggregated;
};

export function aggregation_cache_aggregate(cache) {
	let aggregated = {};
	for (let client_mac in cache.clients) {
		let aggregation_result = aggregation_cache_aggregate_client(cache, client_mac);
		if (aggregation_result != null)
			aggregated[client_mac] = aggregation_result;
	}
	return aggregated;
};