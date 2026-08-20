include $(TOPDIR)/rules.mk

PKG_NAME:=fnsh-node-migrator
PKG_VERSION:=1

include $(INCLUDE_DIR)/package.mk

define Package/fnsh-node-migrator
  SECTION:=admin
  CATEGORY:=Administration
  DEPENDS:=+uci
  TITLE:=Migrate nodes to correct update source
endef

define Build/Compile
endef

define Package/fnsh-node-migrator/install
	$(INSTALL_DIR) $(1)/lib/gluon/upgrade
	$(INSTALL_BIN) ./files/007-fnsh-node-migrator-firstboot $(1)/lib/gluon/upgrade/
	$(INSTALL_BIN) ./files/955-fnsh-node-migrator $(1)/lib/gluon/upgrade/
endef

$(eval $(call BuildPackage,fnsh-node-migrator))
