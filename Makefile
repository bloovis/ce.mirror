ce : src/ce.cr src/ll.cr src/buffer.cr src/line.cr src/keymap.cr
	crystal build --no-color --error-trace src/ce.cr

% : %.cr
	crystal build --no-color --error-trace $<
