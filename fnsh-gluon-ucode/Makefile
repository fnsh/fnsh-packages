include $(TOPDIR)/rules.mk

PKG_NAME:=fnsh-gluon-ucode

PKG_MAINTAINER:=David Bauer <mail@david-bauer.net>
PKG_LICENSE:=BSD-2-Clause
PKG_VERSION:=1.0

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk

define Package/fnsh-gluon-ucode
  SECTION:=gluon
  CATEGORY:=Gluon
  DEPENDS:=+libplatforminfo +libgluonutil +ucode +ucode-mod-uci +ubox
  TITLE:=Gluon ucode library
endef

define Package/fnsh-gluon-ucode/install
	$(INSTALL_DIR) $(1)/usr/lib/ucode/gluon/native $(1)/usr/share/ucode/gluon

	$(CP) $(PKG_BUILD_DIR)/util.so $(1)/usr/lib/ucode/gluon/native/util.so
	$(CP) $(PKG_BUILD_DIR)/platform.so $(1)/usr/lib/ucode/gluon/native/platform.so
	$(CP) $(PKG_BUILD_DIR)/system.so $(1)/usr/lib/ucode/gluon/native/system.so

	$(CP) ./files/pretty-hostname.uc $(1)/usr/share/ucode/gluon/pretty-hostname.uc
	$(CP) ./files/nl80211.uc $(1)/usr/share/ucode/gluon/nl80211.uc
endef

$(eval $(call BuildPackage,fnsh-gluon-ucode))
