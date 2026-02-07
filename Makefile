ce : $(wildcard src/*.cr)
	./get_version.rb
	crystal build --no-color --error-trace src/ce.cr

% : %.cr
	crystal build --no-color --error-trace $<

.PHONY: docs viewdocs
docs:
	crystal docs
viewdocs:
	xdg-open docs/index.html
