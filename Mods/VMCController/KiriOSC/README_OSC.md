# Kiri's OSC Plugin

Simple [OSC](https://ccrma.stanford.edu/groups/osc/spec-1_0.html) 1.0
server for [Godot](https://godotengine.org/), version 3.5.x, and
written in GDScript (no native C++ modules required).

## OSC Server Use

Runs a UDP listener on a given port and IP, parses OSC packets coming
in via UDP, and emits signals when packets are received.

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

## OSC Client Use

Runs a UDP client on a given port and IP, takes in dictionaries and argument
types via public functions. Formats and sends OSC bundles and messages.

- Add a KiriOSCClient node to your scene.
- Set the IP on the node.
- Set the port on the node.
- Set whether to auto start (disabled by default)
- If not using auto start, you will need to use the function start_client().
- Use the public functions available such as send_osc_message to send messages.
- Optionally prepare your messages and use send_osc_message_raw, preparing
  allows for bundling or using functions like prepare_osc_message_auto_type_tag

## Stuff Not Implemented

This is not a full OSC implementation. Due to being a minimal
implementation to support receiving [VMC
protocol](https://protocol.vmc.info/english) from specific
applications, it's lacking the following features:

- Receiving via TCP instead of UDP.
- Address pattern matching.

These may be implemented some day down the road.
