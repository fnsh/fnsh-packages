include $(TOPDIR)/rules.mk

PKG_NAME:=fnsh-ucode-wifi-lib

PKG_MAINTAINER:=David Bauer <mail@david-bauer.net>
PKG_LICENSE:=GPL-2.0-only
PKG_VERSION:=1.0

include $(INCLUDE_DIR)/package.mk

define Package/fnsh-ucode-wifi-lib
  SECTION:=gluon
  CATEGORY:=Gluon
  DEPENDS:=+ucode
  TITLE:=Provides library for handling WiFi related functionality
endef

define Build/Compile
endef

define Package/fnsh-ucode-wifi-lib/install
	$(INSTALL_DIR) $(1)/usr/share/ucode/fnsh/wifi

	$(CP) ./files/beacon.uc $(1)/usr/share/ucode/fnsh/wifi/beacon.uc
	$(CP) ./files/data.uc $(1)/usr/share/ucode/fnsh/wifi/data.uc
	$(CP) ./files/tlv.uc $(1)/usr/share/ucode/fnsh/wifi/tlv.uc
endef

$(eval $(call BuildPackage,fnsh-ucode-wifi-lib))
