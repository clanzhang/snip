.PHONY: build install uninstall run clean help

PREFIX        ?= /usr/local
BINDIR        := $(PREFIX)/bin
TARGET        := .build/release/clipdoctor
SOURCES       := $(wildcard Sources/clipdoctor/*.swift)
SWIFTC_FLAGS  := -O -whole-module-optimization

help: ## 显示帮助
	@echo "用法:"
	@echo "  make build       编译 release 版本"
	@echo "  make install     安装到 $(BINDIR)/clipdoctor"
	@echo "  make uninstall   卸载"
	@echo "  make run         直接运行（调试用）"
	@echo "  make clean       清理编译产物"

build: $(TARGET) ## 编译

$(TARGET): $(SOURCES)
	@mkdir -p $(dir $(TARGET))
	swiftc $(SWIFTC_FLAGS) -o $@ $(SOURCES) -framework AppKit -framework Foundation
	@echo "✅ 编译完成: $@"

install: build ## 安装到系统路径
	@mkdir -p "$(BINDIR)"
	cp "$(TARGET)" "$(BINDIR)/clipdoctor"
	chmod +x "$(BINDIR)/clipdoctor"
	cp scripts/snip "$(BINDIR)/snip"
	chmod +x "$(BINDIR)/snip"
	@echo "✅ 已安装到 $(BINDIR)/clipdoctor"
	@echo "   管理命令: snip {start|stop|status|log|restart}"

uninstall: ## 卸载
	rm -f "$(BINDIR)/clipdoctor" "$(BINDIR)/snip"
	@echo "✅ 已卸载"

run: build ## 运行
	$(TARGET)

clean: ## 清理
	rm -rf .build
	@echo "✅ 已清理"