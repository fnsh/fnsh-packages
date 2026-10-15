include $(TOPDIR)/rules.mk

PKG_NAME:=fnsh-beacon-report-collector

PKG_MAINTAINER:=David Bauer <mail@david-bauer.net>
PKG_LICENSE:=GPL-2.0-only
PKG_VERSION:=1.0

include $(INCLUDE_DIR)/package.mk

define Package/fnsh-beacon-report-collector
  SECTION:=gluon
  CATEGORY:=Gluon
  DEPENDS:=+ucode +fnsh-ucode-wifi-lib
  TITLE:=Collects and aggregates beacon reports from connected clients
endef

define Build/Compile
endef

define Package/fnsh-beacon-report-collector/install
	$(INSTALL_DIR) $(1)/usr/share/ucode/fnsh/wifi $(1)/usr/bin $(1)/etc/init.d

	$(INSTALL_BIN) ./files/beacon-report-collector.uc $(1)/usr/bin/beacon-report-collector
	$(INSTALL_BIN) ./files/beacon-report-collector.init $(1)/etc/init.d/beacon-report-collector
	$(CP) ./files/lib/beacon-report.uc $(1)/usr/share/ucode/fnsh/wifi/beacon-report.uc
endef

$(eval $(call BuildPackage,fnsh-beacon-report-collector))
