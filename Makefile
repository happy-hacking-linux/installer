all: clean build

create-iso: clean build
	@./create-iso.sh

build:
	@echo "Building dist/install"
	@cat vars.sh timezone-selector.sh funcs.sh dialogs.sh steps.sh > dist/install
	@chmod +x ./dist/install

clean:
	@echo "Cleaning..."
	@-rm dist/install 2> /dev/null || true
	@-rm install-vars* 2> /dev/null || true
