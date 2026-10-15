
export function tlv_list_from_octet_array(input_array) {
	let tlvs = [];
	let octet_array = slice(input_array);

	while (length(octet_array) > 2) {
		let type = shift(octet_array);
		let tlv_len = shift(octet_array);
		if (length(octet_array) < tlv_len)
			break;
		let value = [];
		for (let i = 0; i < tlv_len; i++)
			push(value, shift(octet_array));
		push(tlvs, { type: type, length: tlv_len, value: value });
	}

	return tlvs;
};
