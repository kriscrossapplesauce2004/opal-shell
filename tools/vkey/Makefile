PROTO = virtual-keyboard-unstable-v1

vkey: vkey.c $(PROTO)-client-protocol.h $(PROTO)-protocol.c
	$(CC) -O2 -o $@ vkey.c $(PROTO)-protocol.c `pkg-config --cflags --libs wayland-client xkbcommon`

$(PROTO)-client-protocol.h: $(PROTO).xml
	wayland-scanner client-header $< $@

$(PROTO)-protocol.c: $(PROTO).xml
	wayland-scanner private-code $< $@

clean:
	rm -f vkey $(PROTO)-client-protocol.h $(PROTO)-protocol.c

.PHONY: clean
