include $(TOPDIR)/rules.mk

PKG_NAME:=fnsh-beacon-report-submission

PKG_MAINTAINER:=David Bauer <mail@david-bauer.net>
PKG_LICENSE:=GPL-2.0-only
PKG_VERSION:=1.0

include $(INCLUDE_DIR)/package.mk

define Package/fnsh-beacon-report-submission
  SECTION:=gluon
  CATEGORY:=Gluon
  DEPENDS:=+ucode +ucode-mod-uclient +fnsh-ucode-wifi-lib
  TITLE:=Aggregate, anonymize and submit beacon reports
endef

define Build/Compile
endef

define Package/fnsh-beacon-report-submission/install
	$(INSTALL_DIR) $(1)/usr/bin $(1)/etc/init.d $(1)/etc/config 

	$(INSTALL_BIN) ./files/beacon-report-submission.uc $(1)/usr/bin/beacon-report-submission
	$(INSTALL_BIN) ./files/beacon-report-submission.init $(1)/etc/init.d/beacon-report-submission
	$(CP) ./files/beacon-report-submission.uci $(1)/etc/config/beacon-report-submission
endef

$(eval $(call BuildPackage,fnsh-beacon-report-submission))
