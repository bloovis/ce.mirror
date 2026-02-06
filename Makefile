ce : $(wildcard src/*.cr)
	./get_version.rb
	crystal build --no-color --error-trace src/ce.cr

% : %.cr
	crystal build --no-color --error-trace $<
