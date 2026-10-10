include $(TOPDIR)/rules.mk

PKG_NAME:=fnsh-wan-limit

PKG_MAINTAINER:=David Bauer <mail@david-bauer.net>
PKG_LICENSE:=GPL-2.0-only
PKG_VERSION:=1.0

include $(INCLUDE_DIR)/package.mk

define Package/fnsh-wan-limit
  SECTION:=gluon
  CATEGORY:=Gluon
  DEPENDS:=+ucode +kmod-sched-cake +kmod-ifb +tc
  TITLE:=Allows configuring a bandwidth-limit for the WAN port, including VPN as well as private-WiFi
endef

define Build/Compile
endef

define Package/fnsh-wan-limit/install
	$(INSTALL_DIR) $(1)/lib/gluon/fnsh $(1)/etc/hotplug.d/iface

	$(CP) ./files/wan-limit.uc $(1)/lib/gluon/fnsh/wan-limit.uc
	$(CP) ./files/hotplug.sh $(1)/etc/hotplug.d/iface/85-fnsh-wan-limit
endef

$(eval $(call BuildPackage,fnsh-wan-limit))
