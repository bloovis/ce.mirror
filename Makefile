ce : $(wildcard src/*.cr)
	crystal build --no-color --error-trace src/ce.cr

% : %.cr
	crystal build --no-color --error-trace $<
