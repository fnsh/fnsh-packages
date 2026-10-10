#!/usr/bin/ucode

import * as uci from 'uci';
import * as fs from 'fs';

let MIN_BANDWIDTH = 1500;

function read_config() {
	let uci_cursor = uci ? uci.cursor() : null;
	let return_value = null;
	uci_cursor.load('gluon');
	uci_cursor.foreach('gluon', 'fnsh_wan_limit', (section) => {
		let config = {
			enabled: false,
			ingress: null,
			egress: null,
		};

		if (section.enabled == '1')
			config.enabled = true;

		if (section.ingress != null)
			config.ingress = int(section.ingress);

		if (section.egress != null)
			config.egress = int(section.egress);

		if (config.ingress == NaN && config.egress == NaN)
			return null;

		if (config.ingress == NaN || config.ingress < MIN_BANDWIDTH)
			config.ingress = null;

		if (config.egress == NaN || config.egress < MIN_BANDWIDTH)
			config.egress = null;

		return_value = config;
	});

	return return_value;
};

function read_interface_name(ifname) {
	let path = "/lib/gluon/core/sysconfig/" + ifname + "_ifname";
	
	return fs.readfile(path);
};

function get_wan_interface() {
	let ifnames = [ "single", "wan" ];
	for (let ifname in ifnames) {
		try {
			let hardif = read_interface_name(ifname);
			return trim(hardif);
		} catch (e) {
		}
	}
	return null;	
};

function set_bandwidth(ifname, bandwidth) {
	let tc_command = "tc qdisc replace dev " + ifname + " root cake bandwidth " + bandwidth + "kbit besteffort";
	system(tc_command);
};

function remove_shaper(iface) {
	system("tc qdisc del dev " + iface + " root");
};

function create_ifb(iface) {
	system("ip link add name ifb-wan type ifb");
	system("ip link set dev ifb-wan up");
};

function enable_ifb_redirect(iface) {
	system("tc qdisc del dev " + iface + " handle ffff: ingress");
	system("tc qdisc add dev " + iface + " handle ffff: ingress");
	system("tc filter replace dev " + iface + " parent ffff: protocol all prio 10 u32 match u32 0 0 flowid 1:1 action mirred egress redirect dev ifb-wan");
};

function delete_ifb(iface) {
	system("ip link del dev ifb-wan");
	system("tc qdisc del dev " + iface + " handle ffff: ingress");
};


let config = read_config();
let wan_ifname = get_wan_interface();

if (wan_ifname == null) {
	print("Could not determine WAN interface\n");
	exit(1);
}

if (config == null || !config.enabled) {
	delete_ifb(wan_ifname);
	remove_shaper(wan_ifname);
} else {
	if (config.egress != null) {
		set_bandwidth(wan_ifname, config.egress);
	} else {
		remove_shaper(wan_ifname);
	}

	if (config.ingress != null) {
		if (!fs.access('/sys/class/net/ifb-wan'))
			create_ifb(wan_ifname);
		enable_ifb_redirect(wan_ifname);
		set_bandwidth("ifb-wan", config.ingress);
	} else {
		delete_ifb(wan_ifname);
	}
}
print('Set bandwidth for Interface ', wan_ifname, ' to ', config.egress, 'kbit/s up / ', config.ingress, 'kbit/s down', '\n');
