import * as fnsh_wifi_data from 'fnsh.wifi.data';

export function beacon_elements_parse_ssid(beacon_data) {
	for (let tlv in beacon_data) {
		if (tlv.type != 0) {
			continue;
		}

		let ssid = "";
		for (let i = 0; i < length(tlv.value); i++) {
			if (tlv.value[i] == 0)
				continue;
			ssid += uchr(tlv.value[i]);
		}

		return ssid;
	}
	return "";
};

export function beacon_elements_parse_qbss_load(beacon_data) {
	for (let tlv in beacon_data) {
		if (tlv.type != 11) {
			continue;
		}

		if (tlv['length'] != 5)
			continue;

		let station_count = 0;
		let channel_utilization = 0;

		/* ToDo: Decode value, assume max 255 for now :) */
		station_count = tlv['value'][0];
		channel_utilization = tlv['value'][2];

		return { station_count: station_count, channel_utilization: channel_utilization };
	}
	return null;
};

export function beacon_elements_parse_vendor_specific(beacon_data, oui, vendor_specific_type) {
	for (let tlv in beacon_data) {
		if (tlv.type != 221) {
			continue;
		}

		if (tlv['length'] < 4)
			continue;

		let next = false;
		for (let i = 0; i < 3; i++) {
			if (tlv['value'][i] != oui[i]) {
				next = true;
				break;
			}
		}
		if (next)
			continue;

		/* Check vendor specific type */
		if (tlv['value'][3] != vendor_specific_type)
			continue;

		let value = [];
		for (let i = 4; i < tlv['length']; i++) {
			push(value, tlv['value'][i]);
		}

		return value;
	}
	return null;
};

export function beacon_elements_parse_owe_transition_ssid(beacon_data) {
	let vs_element = beacon_elements_parse_vendor_specific(beacon_data, [0x50, 0x6F, 0x9A], 28);

	if (length(vs_element) < 8)
		return null;

	let bssid = "";
	for (let i = 0; i < 6; i++) {
		bssid += fnsh_wifi_data.hexencode_octet(vs_element[i]);
		if (i < 5) {
			bssid += ":";
		}
	}

	let ssid_len = vs_element[6];

	if (ssid_len <= 0 || 6 + ssid_len > length(vs_element))
		return null;

	let ssid = "";
	for (let i = 7; i < 7 + ssid_len; i++) {
		if (vs_element[i] == 0)
			continue;
		ssid += uchr(vs_element[i]);
	}

	return { bssid: bssid, ssid: ssid };
};
