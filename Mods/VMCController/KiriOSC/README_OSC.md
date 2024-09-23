# Kiri's OSC Plugin

Simple [OSC](https://ccrma.stanford.edu/groups/osc/spec-1_0.html) 1.0
server for [Godot](https://godotengine.org/), version 3.5.x, and
written in GDScript (no native C++ modules required).

Runs a UDP listener on a given port and IP, parses OSC packets coming
in via UDP, and emits signals when packets are received.

## Use

- Add a KiriOSCServer node to your scene.
- Set the host IP on the node. (Use 0.0.0.0 for all IPs, 127.0.0.1 for
  local connections only.)
- Set the host port on the node.
- Connect the "message_received" signal from the node to your code.
  (Node tab->Signals->message_received, "Connect...", or use the
  connect() command.)
- Receiving OSC messages on the port will cause the signal to fire.
  Filtering addresses must be done in the receiving function. (TODO:
  Write address matching utility function.)

## Stuff Not Implemented

This is not a full OSC implementation. Due to being a minimal
implementation to support receiving [VMC
protocol](https://protocol.vmc.info/english) from specific
applications, it's lacking the following features:

- Sending messages.
- Receiving via TCP instead of UDP.
- Address pattern matching.

These may be implemented some day down the road.

