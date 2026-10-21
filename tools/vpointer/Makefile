PROTO = wlr-virtual-pointer-unstable-v1

vpointer: vpointer.c $(PROTO)-client-protocol.h $(PROTO)-protocol.c
	$(CC) -O2 -o $@ vpointer.c $(PROTO)-protocol.c `pkg-config --cflags --libs wayland-client`

$(PROTO)-client-protocol.h: $(PROTO).xml
	wayland-scanner client-header $< $@

$(PROTO)-protocol.c: $(PROTO).xml
	wayland-scanner private-code $< $@

clean:
	rm -f vpointer $(PROTO)-client-protocol.h $(PROTO)-protocol.c

.PHONY: clean
