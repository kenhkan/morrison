# Vyzzi

Vyzzi is an FBP toolchain built on the ideas of [classical Flow-Based
Programming](http://www.jpaulmorrison.com/fbp/). It is designed to run a
network (i.e. a program in FBP) on a single Unix-like machine. It:

- fetches components via different sourcing protocols like git and HTTP;
- provides wrappers and adapters for programs not written with Vyzzi in
  mind;
- compiles network specification files into a bash program; and
- links the different components that may have the same names
  without conflicts while avoids employing a "sub-dependency" strategy like
  what Node.js' npm does; and

For those looking for:

- [what Vyzzi aims at solving](#goals-and-non-goals).
- [how Vyzzi is different from FBP](#differences-from-classical-fbp-cfbp).
- [creating a component](#component-specification).
- [creating an FBP-aware component](#writing-fbp-aware-components).
- [sharing a component](#sharing-the-component).
- [contributing to Vyzzi](#contributing).
- [requesting for a feature](#personas).
- [the glossary](#glossary).

## Philosophy

### Goals and non-goals

Vyzzi is language-agnostic. If a program runs on a Unix-like machine, it
qualifies as a component candidate. The program may not even be aware that it
is running as a component. One component may be in Ruby while another in Rust;
and there is no SDK for the program to interact with.

It targets software designed to run in a modern server-grade Unix-like
environment. It does not aim to run in the browser, on Windows, or on embedded
hardware. Frontend FBP (like a GUI) is out of scope.

A main focus of Vyzzi is software correctness and collaboration over
performance. The use of Unix processes and Unix IPC makes Vyzzi relatively
inefficient compared to a framework designed in a specific language. The
advantage is that existing programs can readily turn into components and teams
with different preferences on technology choices can collaborate without tight
coupling between different parts of the system.

There is a single machine assumption. Parallelism is a non-trivial topic and is
best tackled at a different level on top of Vyzzi. Vyzzi is only concerned with
coordinating interdependent parts of a piece of software on a single machine.

### Differences from classical FBP (cFBP)

Vyzzi is inspired by cFBP and is an almost faithful implementation of cFBP.
However, there are some differences, described in the sections below.

Note that despite the minor differences, the two major constraints of FBP, the
flow constraint and the order-preserving constraint, [1] are enforced.

The three legs of FBP [2] also hold for Vyzzi:

- asynchronous processes
- data packets (IPs) with a lifetime of their own
- external definition of connections

#### Data packets (IPs) with a lifetime of their own

Technically there is a lifetime for each IP. However, for a component that is
not FBP-aware (i.e. Vyzzi provides a wrapper that marshals data between the FBP
world and the Unix world), the IP is created on sending and destroy on
receiving.

This does not violate FBP principles, but may be "awkward" to some that an IP
in between two FBP-unaware components does not travel anywhere else.

#### Tree structures

Implementing tree structures is non-trivial while respecting Unix semantics.
This has not been implemented in Vyzzi.

*TODO* Provide an Issue.

## Component specification

Each component requires a manifest file so that Vyzzi knows how to deal with
it. In fact, only the manifest file is needed to source and build a component.
This section is split into several sub-sections for ease of human consumption
but they all belong in a single manifest file in practice.

A manifest file is written in [YAML](http://yaml.org/) for its maturity,
human-friendliness, and support for comments. The manifest file must be named
`Vyzzi.yml`.

### Versioning

There must be a version designation in the manifest file:

```yaml
version: 1
```

The version is only an ever-increasing integer. Version is incremented when
there is a conflicting change in the way a key is used in the manifest.

For simplicity, not only is this the version for the manifest, it is also the
version of the compiler and runtime. In other words, whenever there is *ANY*
conflicting change, be it a key name in the manifest, the behavior of the
compiler, or what the runtime provides as its interface, the version is
incremented.

Employing a monolithic versioning approach removes the confusion when there is
an unexpected behavior and it is unclear where the change has been.

### Inter-component communication

Just like web services communicate with each other with HTTP connections in a
RESTful architecture, a component in FBP communicates with another with an FBP
connection.

A connection is a stream. Just like there is a stream of messages in a
WebSocket connection over TCP, an FBP connection is a stream of Information
Packets, or IPs. Unlike a WebSocket connection, however, an FBP connection is
uni-directional.

Each component defines its ports. Like a TCP port, all data going through a
connection pass through a designated port. Each FBP port however is designated
as an input port or an output port when the component is designed; in contrast,
a TCP port can be used both to send and to receive.

In cFBP, IPs are explicitly created or destroyed by a component. In Vyzzi,
there is an open-world assumption that components are not expected to "know"
that they are in the Vyzzi world. Coupled with that all data transmitted across
the network are copied, this assumption leads to the design choice for Vyzzi to
implicit create and destroy IPs on behalf of the component.

For Vyzzi to manage the IPs, it needs to understand the delimiting convention
that a particular component uses. Vyzzi requires the component to specify how
it sends and receives its data, by specifying the `ports` section in the
component manifest.

```yaml
ports:
  input | output:
    <port name>:
      grouping-type: none | flat | hierarchical
      close-packet: <array of bytes>
      open-bracket: <array of bytes>
      close-bracket: <array of bytes>
```

For example:

```yaml
ports:
  input:
    one-inport-name:
      grouping-type: flat
      # CSV
      close-packet: [44] # Comma
      open-bracket: []
      close-bracket: [10] # Newline
    another-inport-name:
      grouping-type: hierarchical
      # Parenthesized list
      close-packet: [44] # Comma
      open-bracket: [40] # Open parenthesis
      close-bracket: [41] # Close parenthesis
    yet-another-inport-name:
      grouping-type: none
      # Unix style: each line is an IP.
      close-packet: [10] # Newline
      open-bracket: []
      close-bracket: []
  output:
    an-outport-name:
      grouping-type: flat
      # Multi-byte delimiters
      close-packet: [255, 12] # East Asian character comma in UTF-16
      open-bracket: []
      close-bracket: [48, 2] # East Asian character period in UTF-16
```

In the manifest, each port corresponds to a set of delimiter definitions: its
grouping type, packet closing delimiter, bracket opening delimiter, and bracket
closing delimiter. The available delimitering types are:

- `none`: The stream consists of packets separated by some delimiter but
  there is only one level. It is useful for a component that only cares about
  receiving its data in chunks, each pair of which is demarcated by a common
  token. An example is a component that takes in C-style strings (i.e.
  null-terminated) and produces a number of strings. The marker would be the
  null character and it does not care about grouping.
- `flat`: The stream consists of packets of exactly ONE level. Every
  time a packet arrives that is NOT in a bracket already, it automatically
  opens a new bracket. An example is CSV. Each line is considered a group and
  no data may be outside of a group.
- `hierarchical`: This enables the full power of FBP. A stream
  consists of packets, groups of more packets, and/or groups of groups.
  Examples include transmitting hierarchical data structures like JSON and XML.
  However, note that JSON/XML cannot be fully expressed because they support
  properties.

Each of the delimiter definitions is an array of bytes in decimal. Vyzzi does
not care about the character encoding. At compile time, Vyzzi matches the
delimiter specification of the two ports in each connection. If they do not
agree, Vyzzi would insert an adapter to convert one to another.

### Delimiter conversion rules

Conversion may go with any one of three ways:

1. From one delimitering type to the same delimitering type. For example, a
   component sends in CSV and another receives in TSV. The two use different
   formats but the delimitering type is the same, most likely with `flat`.
2. From a "lower" type to a "higher" type. An example would be sending CSV
   (most likely a `flat`) to a component that expects a symbolically JSON
   structure (a `hierarchical`).
3. From a "higher" type to a "lower" type. Think symbolic JSON to CSV, the
   oppposite of the previous example.

There is no surprise on the first kind of conversions. It's a simple map from
one set of delimiter to another.

The second one is tricky. Going from `none` to `flat` requires no change
because `flat` does not require brackets anyway. Going from `flat` to
`hierarchical` is disallowed because of the ambiguity of whether and where to
insert the open brackets.

The third one is equally tricky. For conversion from either `hierarchical` or
`flat` to `none`, the conversion is simple as Vyzzi can simply drop all
brackets. For `hierarchical` to `flat`, it's disallowed because of disambiguity
in the semantics of the output.

To achieve the disallowed conversion types, insert a component in between the
two that would perform the correct marshalling behavior.

#### The responsibility of Vyzzi in delimiter conversion

There are some structures that cannot be expressed with this delimitering
specification. For instance, proper CSV cannot be expressed as it allows
escaping delimiter characters by quoting a field (e.g. `a,b,"c, d, and e",f`).
Another example is JSON. Properties (e.g. `{"a": 1}`) cannot be represented
with delimitering.

It is not the responsibility of Vyzzi to provide a way to automagically convert
every format into every other format. It provides these delimitering options
only to fully honor the FBP concept of an Information Packet. And it is
certainly not Vyzzi's job to impose a particular world view onto how all
components should communicate.

This is a design decision that the network developer needs to make. For the CSV
example above, a possible approach would be to have a CSV parser that takes a
connection in which each IP is the content of a CSV file, and outputs the
constituent parts in individual IPs delimitered by something other than commas
and newlines. For this to work, the receiving component would need to expect
delimiters other than commas and newlines as well, though the delimiters need
not be the same as those used by the sending component.

In other words, the developer of each individual component chooses its own set
of delimiters, knowing that they do not conflict with the content of the IPs.
Vyzzi only takes care of matching the delimiter sets, but not what those sets
are.

#### Where is open packet?

There is a `close-packet` but not a `open-packet`. Vyzzi assumes that all data
in a connection to be well-formed. And so once a packet has closed, a bracket
has closed, or the connection has just been opened, it assumes that the
upcoming data is part of a packet.

#### Port names

Input and output ports have distinct namespaces. Port names may contain
alphanumeric characters and dashes. Vyzzi compiles port names into integer
values (Unix file descriptors) for execution.

### Elementary component specification

For elementary components, Vyzzi needs six questions answered:

1. Where to source the program?
2. How do we build the program?
3. How to run the program?
4. What environment variables does the program expect?
5. What parameters does it expect?
6. What I/O streams does it expect?

#### The specification

```yaml
elementary:
  source:
    protocol: git | http
    url: <URL to source>
    format: git | tgz | tbz
    working-directory: <path to a sub directory within the archive to start the build process>
  build:
    nix | mac | freebsd | ubuntu | centos: <build command to run in the specified operating systems>
    <... more OS build definitions ...>
  path: <path to the program to run after building, relative to the working directory>
  fbp-aware: true | false
  expectations:
    terminate: on-exit | on-error
    environment-variables: <an associative array of case insensitive names to case sensitive names>
    parameters: <an array of case insensitive names>
    input-streams: <an array of case insensitive names>
    output-streams: <an array of case insensitive names>
```

##### Building

`build` is not restricted to compilation. Even if the program runs interpreted,
like a Python or a Node.js script, installing the necessary runtime is the
responsibility of the `build` commands.

When building, Vyzzi runs the build command defined for each OS label that
matches the host operating system. For instance, one component may be defined
as:

```yaml
elementary:
  build:
    unix-like: make
    macos: brew install wget
    freebsd: pkg_add -r wget
```

For a macOS host, `make` and `brew install wget` would run in the directory as
defined by `working-directory` in the `source` section. The order is always
from the more general label to the more specific label. `unix-like` always runs first
for all Unix-like hosts.

If any of the build commands exits with a non-zero status code, the network
would fail to compile.

##### I/O

In the `environment-variables` attribute, the keys are case insensitive just
like parameters and streams, but the values are case sensitive so that the
wrapper can correctly specify the environment variables that the underlying
program expects.

`parameters`, `input-streams`, and `output-streams` must be an ordered array of
names because their orders are significant with Unix pipes.

#### Process deactivation and termination

In cFBP, there is a distinction between deactivation and termination. A
deactivated process has finished running but may be activated again on incoming
IPs, whereas a terminated process has ended execution for good and will never
be started again, until the network is initiated again.

In Vyzzi, by default, a process is always terminated when the internal logic
returns with any exit code. That is, `terminate` is set to `on-exit`.

To implement a component that deactivates rather than terminates upon exiting,
set the property `terminate` to `on-error`. A process which is set to terminate
on error always deactivates, unless the internal logic returns a _non-zero_
exit code. Such a process is only terminated either on error or all its
upstream processes have terminated.

If an `_on-termination_` output port is attached to a process, the exit code of
the source process is sent in an IP to the corresponding target process when
the source process terminates.

#### FBP awareness

A primary principle of Vyzzi is to not require elementary components to be
FBP-aware. This inclusive principle allows Vyzzi to leverage as much
well-written and already battle-tested software into the FBP world as possible.

For these FBP-unaware components, Vyzzi marshalls data between the FBP world
and the Unix world. For an FBP-aware component, Vyzzi naturally relies on the
component to handle the data at a lower level. See the section [Writing
FBP-aware components](#writing-fbp-aware-components) for more information on
how to write such a component.

### Composite component specification

If the component is a network, Vyzzi needs two things:

1. What sub-components are used?
2. Which ports of each sub-component are used and where are they attached to?

#### The specification

```yaml
composite:
  substream-sensitivity: true | false
  processes:
    <name of one process in this network>:
      source:
        type: local | registry | private
        # Only for `local`
        path: <path to a component manifest file on the local filesystem>
        # Only for `registry`
        name: <a component name in the registry>
        version: <the component's registry version>
        # Only for `private`
        url: <URL to a private component manifest>
      input:
        <name of an input port of another process>:
          connected-process: <name of the connected process>
          connected-port: <name of the connected port> | _on-termination_
        <name of an input port of the parent network>:
          connected-process: _network_
          connected-port: <name of the connected port>
        <... more input port definitions ...>
      output:
        <name of an output port of another process>:
          connected-process: <name of the connected process>
          connected-port: <name of the connected port> | _activate_
        <name of an output port of the parent network>:
          connected-process: _network_
          connected-port: <name of the connected port>
        <... more output port definitions ...>
    <... more process definitions ...>
```

We use the term "processes" to refer to instances of components. As a network
may contain the same component used in different ways, each of those component
instances is a process.

The name of a process in this network (i.e. the key of the `processes`
associative array) is an arbitrary name (alphanumeric and dashes) for this
particular instance. It is required so that we can specify to which process a
port is connected.

Set `connected-process` to `_network_` to connect to a port of the network that
is using the process as its sub-component.

`connected-port` may be set to `_on-termination_` for an input port to receive
IPs when another process has terminated and set to `_activate_` for an output
port to send an IP to activate another process.

Note that `_network_` cannot be used in conjunction with the two special ports
because a child process cannot effect its parent network.

### Sharing the component

Components are meant to be re-used so that the wheel is not re-invented over
and over again. A component can be shared on the Vyzzi registry by specifying a
`registry` section in the manifest and pushing it to the registry.

```yaml
registry:
  name: <the component name>
  version-label: <the program's version>
  summary: <a short blurb to show in search and the component info page>
  homepage: <URL to home page of the component>
  email: <email address to contact for question>
  license:
    type: <license type>
    url: <URL to the license>
```

The component name is in the form of `<username>/<component name>`, where
`<username>` is a registered user in the Vyzzi registry. For instance,
`core/copy`.

Note that one does not specify a version for the component but a version
"label". The Vyzzi registry is versioning scheme agnostic. Each time a
component is pushed, it simply records a new version. The canonical version
scheme is just an incrementing integer. `version-label` is only for users when
browsing the registry.

`<license type>` may be one of:

- All rights reserved
- Apache License 2.0
- BSD 2-Clause
- BSD 3-Clause
- GNU AGPLv3
- GNU GPLv3
- GNU LGPLv3
- MIT License
- Mozilla Public License 2.0
- Public
- Other (`url` in `license` is required if selected)

#### Pushing the component to the registry

*TODO*

## Writing FBP-aware components

Sometimes the component developer does not want Vyzzi to automatically marshal
data so that a Unix-like program just works. A scenario is when array ports are
needed. The concept of array ports is unique to FBP, an equivalent to which
does not exist in the Unix-like world. In that case, the developer must write
the wrapper herself to leverage the feature.

An FBP-aware component designates itself as such by setting the attribute
`elementary.fbp-aware` to `true`. A side-effect of this is that all automatic
data marshalling enabled by `elementary.expectations` are ignored given that
the component has volunteered to take control.

Note that only an elementary component may be designated FBP-aware. A composite
component is automatically FBP-aware given that its constituent parts need to
be FBP-aware to begin with.

### Ports

An FBP-unaware component simply reads from I/O streams. Its FBP-aware
counterpart may also choose to do that, but it may also choose to select by
port name rather than I/O stream. This is especially crucial for array ports.

Array ports allow a process to selectively receive IPs from a number of
"sub-ports" in a single port. A Unix program, however, cannot separate out data
once it merges into a single stream accessible via a file descriptor.

An FBP-aware component may use array ports by reading the environment variable
`VYZZI_PORT_MAP_PATH`. It is the path to a file that contains mapping for
ports.

#### Port map file protocol

Each map file is tab-separated values of the following format:

```
IN | OUT    <port name>    <starting file descriptor>    <file descriptor count>
```

Note that the spaces above are tabs in practice.

An example would be:

```
IN  IN  0   1
IN  ArrayPort-1  2   4
OUT OUT 6   1
IN  ArrayPort-2  7   3
OUT NormalPort   10  1
```

There is one `IN` input port; `ArrayPort-1` has 4 sub-ports starting at file
descriptor 2, and so on.

The component would read from this file, whose path is provided as
`VYZZI_PORT_MAP_PATH`, and a just simple lookup is required to accomplish
reading by port name.

### Connection protocol

*TODO*

## Contributing

To contribute, simply fork this repo and create a pull request. Also feel free
to create Github issues based on one of the [personas](#personas).

### A word on licensing

The Vyzzi specification, compiler, and the runtime, as located at
https://github.com/kenhkan/vyzzi, is released under
[AGPLv3](https://www.gnu.org/licenses/agpl-3.0.en.html).

This means that modifying the Vyzzi compiler requires the modification to be
made public under AGPLv3, even when the changes only affect users over a
network connection, although it is not required to be contributed back to this
Vyzzi repository.

What it does not mean is that the executable generated by compiling a network
of components via the Vyzzi compiler is not required to be AGPLv3-compatible.
The licensing of the executable depends solely on the licenses of the
constituent components.

### Personas

These personas are to be used when creating feature requests as Github issues
so we know who the feature is catered to. It is highly encouraged to use Agile
user story format of "As..., I want... so that...".

### Matt

Matt is obsessed with performance. His solutions are not intuitive to most so
they are difficult to maintain, but his creations are usually the most
efficient solutions.

### Mike

Mike is a frontend developer who is fanatical about beautiful and intuitive
design. Perfection is a requirement. His obsession often leads to some of the
most stunning user interfaces.

### Raymond

Just a genius developer. Everyone knows that if she needs a hard problem
solved, Raymond is the person to ask. Given a problem, with somewhat (i.e. not
necessarily perfectly) clear requirements, Raymond can consistently deliver
unexpected results.

### Ryan

Ryan is a manager who is interested in technology but does not code. He learns
how to code on his own to get some understanding of what he manages and
delivers but nonetheless remains largely outside of the development realm. It
would delight him if there is a way he can be closer to his software's
development without needing to be a software engineer.

### Ken

A software engineer who just wants to get stuff done and doesn't want to worry
about maintenance. Managed services are the best things since sliced bread.

### Paul

A veteran engineer who is interested in applying Flow-Based Programming to
advance modern-day computing.

## Glossary

Vyzzi aims to adhere to cFBP as closely as possible, so the vocabulary used is
almost identical as well.

For more FBP definitions, see the [FBP
Glossary](http://www.jpaulmorrison.com/fbp/gloss.htm).

### Program

In the context of Vyzzi, a "program" a is Unix program that runs "inside" a
component. It is not necessarily aware that it is running inside the Vyzzi
world. A wrapper is applied around a program to connect the program to the
Vyzzi world.

### Wrapper

A shim generated by Vyzzi when building a component to connect the underlying
program to the Vyzzi world by mapping Unix I/O concepts (e.g.  parameters,
environment variables, pipes, etc) to cFBP I/O concepts (ports and
connections).

### Adapter

A component generated by Vyzzi when building a component that performs some
conversion between two user-defined components so that they talk to each other
correctly.

### Component

A black box that runs some logic and honors a number of in-ports and out-ports.
The only way to communicate with the internal logic in a component is through
its ports. This may be a wrapped program or a network of sub-components.

### Port

An abstraction that takes some input or some output, but not both. Conceptually
similar to TCP ports, except that FBP ports are by name and uni-directional.

### Connection

Two ports, and by extension two processes, are connected by a connection.

### Information Packet (IP)

In FBP, it is a unit of datum that gets transmitted over a connection at a time
and has a lifetime of its own. In Vyzzi, an IP does not have a lifetime of its
own in the sense that it is automatically created and destroyed upon
sending/receipt.

### Network

A network of components connected together to run some logic and honors a
number of in-ports and out-ports. A network is also a component.

### Subnet

A network. The term is used to distinguish it being part of a larger network.

### Elementary component

A component that is a wrapped program. i.e. not a network.

### Composite component

A network. The term is used to distinguish between elementary components that
are wrapped programs and composite components that are networks of other
sub-components. Also simply referred to as a "composite".

### Substream sensitivitiy

A network developer may set a subnet as "substream sensitive" so that a
substream going into the subnet is treated as a stream. That is, when there is
a closing bracket coming from "outside" of the network, the stream is closed
"inside" the network. See the chapter [Composite
Components](http://www.jpaulmorrison.com/fbp/compos.shtml) in the FBP book for
details.

### Array port

An array port is a port that supports multiple incoming connections (for
in-ports) or multiple outgoing connections (for out-ports). Each sub-port in
an array port is a distinct and independent port from the other (sub-)ports.

### Initial information packet (IIP)

Like an IP, except that it is defined at design time. It is mostly used for
setting initial data.

### Automatic port

Ports that are not part of the component definition but are automatically
available for each component.

An automatic input port activates a process upon receiving an IP, if not
already activated. In Vyzzi it's called `_activate_`.

An automatic output port sends an IP upon the process terminating. In Vyzzi
it's called `_on-termination_`.

## References

1. Morrison, J. Paul (2011-02-26). Flow-Based Programming - 2nd Edition (p. 30)
2. Morrison, J. Paul (2011-02-26). Flow-Based Programming - 2nd Edition (p. 268)
