ce : $(wildcard src/*.cr)
	./get_version.rb
	crystal build --no-color --error-trace src/ce.cr

ce.release : $(wildcard src/*.cr)
	./get_version.rb
	crystal build --no-color --error-trace --release -o ce.release src/ce.cr

% : %.cr
	crystal build --no-color --error-trace $<

.PHONY: docs viewdocs install install-release
docs:
	crystal docs
viewdocs:
	xdg-open docs/index.html

BINDIR = /usr/local/bin
RUBYDIR = /usr/local/share/pe

$(RUBYDIR) :
	sudo mkdir -p $(RUBYDIR)

install : ce $(RUBYDIR)
	sudo cp ce $(BINDIR)
	sudo cp ruby/*.rb $(RUBYDIR)

install-release : ce.release $(RUBYDIR)
	sudo cp ce.release $(BINDIR)/ce
	sudo cp ruby/*.rb $(RUBYDIR)
