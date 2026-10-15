
export function hexencode_octet(octet) {
	let lookup = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'];
	let most_significant_nibble = (octet / 16) & 0xF;
	let least_significant_nibble = octet & 0xF;
	return lookup[most_significant_nibble] + lookup[least_significant_nibble];
};

export function octet_array_to_hex(beacon_body) {
	let out_str = "";
	for (let i = 0; i < length(beacon_body); i++)
		out_str += hexencode_octet(beacon_body[i]);
	return out_str;
};

export function octet_array_from_string(byte_string) {
	let string_array = split(byte_string, '');
	let octet_array = [];
	for (let i = 0; i < length(string_array); i++)
		push(octet_array, ord(string_array[i]));
	return octet_array;
};

export function octet_array_from_base64(base64_string) {
	return octet_array_from_string(b64dec(base64_string));
};

export function octet_array_clone(octet_array) {
	let clone = [];
	for (let i = 0; i < length(octet_array); i++)
		push(clone, octet_array[i]);
	return clone;
};

export function octet_array_parse_uint64(octet_array, offset) {
	if (length(octet_array) < offset + 8) {
		return null;
	}
	return (octet_array[offset] << 56) |
	       (octet_array[offset + 1] << 48) |
	       (octet_array[offset + 2] << 40) |
	       (octet_array[offset + 3] << 32) |
	       (octet_array[offset + 4] << 24) |
	       (octet_array[offset + 5] << 16) |
	       (octet_array[offset + 6] << 8) |
	       octet_array[offset + 7];
};

export function octet_array_parse_uint32(octet_array, offset) {
	if (length(octet_array) < offset + 4) {
		return null;
	}
	return (octet_array[offset] << 24) | (octet_array[offset + 1] << 16) | (octet_array[offset + 2] << 8) | octet_array[offset + 3];
};

export function octet_array_parse_uint16(octet_array, offset) {
	if (length(octet_array) < offset + 2) {
		return null;
	}
	return (octet_array[offset] << 8) | octet_array[offset + 1];
};

export function octet_array_parse_uint8(octet_array, offset) {
	if (length(octet_array) < offset + 1) {
		return null;
	}
	return octet_array[offset];
};

export function octet_array_parse_bool(octet_array, offset_byte, offset_bit) {
	if (length(octet_array) < offset_byte + 1) {
		return null;
	}
	return (octet_array[offset_byte] & (1 << offset_bit)) != 0;
};

export function octet_array_parse_mac(octet_array, offset) {
	if (length(octet_array) < offset + 6) {
		return null;
	}
	let mac_str = '';
	for (let i = 0; i < 6; i++) {
		if (i > 0) {
			mac_str += ':';
		}
		mac_str += hexencode_octet(octet_array[offset + i]);
	}
	return mac_str;
};

export function object_deepclone(obj) {
	// ToDo: Implement proper
	return json(sprintf("%J", obj));
};