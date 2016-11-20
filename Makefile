all: clean build


build:
	@cat vars.sh funcs.sh dialogs.sh steps.sh > dist/install
	@chmod +x ./dist/install

clean:
	@-rm dist/install 2> /dev/null || true
	@-rm -s install-vars* 2> /dev/null || true
