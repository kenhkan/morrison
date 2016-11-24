# Morrison

Morrison is an FBP toolchain built on the ideas of [classical Flow-Based
Programming](http://www.jpaulmorrison.com/fbp/). It is designed to run a
network (i.e. a program in FBP) on a single Unix-like machine. It is a
toolchain that it:

- allows different sourcing protocols like git and HTTP to be used
  when fetching the source of components;
- provides wrappers and adapters for programs not written with Morrison in
  mind;
- compiles network specification files into bash program; and
- links the different components that may have the same names
  without conflicts while avoids employing a "sub-dependency" strategy like
  what Node.js' npm does; and

## Sections

I am interested in...

- [what Morrison aims at solving](#goals-and-non-goals).
- [how Morrison is different from FBP](#differences-from-classical-fbp-cfbp).
- [creating a component](#component-specification).
- [creating a Github issue](#personas).
- [the glossary](#glossary).

## Philosophy

### Goals and non-goals

Morrison is not language-specific or even FBP-specific. If a program runs on a
Unix-like machine, it qualifies as a Morrison component candidate. The program
may not even be aware that it is running as a component. One component may be
in Ruby while another in Rust; and there is no SDK for the program to be
compiled with.

It targets software designed to run in a modern server-grade Unix-like
environment. It does not aim to run in the browser, on Windows, or on embedded
hardware. Frontend FBP (like a GUI) is out of scope.

A main focus of Morrison is software correctness and collaboration over
performance. The use of Unix processes and Unix IPC makes Morrison relatively
inefficient compared to a framework designed in a specific language. The
advantage is that existing programs can readily turn into components and teams
with different preferences on technology choices can collaborate without
coupling with the other parts of the system.

There is a single machine assumption. Parallelism is a non-trivial topic and is
best tackled at a different level on top of Morrison. Morrison is only
concerned with coordinating interdependent processes on a single machine.

### Differences from classical FBP (cFBP)

Morrison is inspired by cFBP but diverges from some of its rules highlighted in
the sub-sections below.

Note that despite the following differences, the two major constraints of FBP,
the flow constraint and the order-preserving constraint, [1] are enforced for
this to work as a valid FBP implementation.

Two of the three legs of FBP [2] also hold for Morrison:

* True: asynchronous processes
* False: data packets (IPs) with a lifetime of their own
* True: external definition of connections

#### Data packets (IPs) with a lifetime of their own

Enforcing IPs with their own lifetime offers the guarantee that a single IP is
not simultaneously used in two processes. This guarantee is rendered
meaningless in Morrison as it maps an FBP process to a Unix system process and
an FBP connection to a Unix pipe. Because of this system-level isolation,
unlike traditional cFBP implementations, the content, rather than the "handle",
of an IP is copied.

The implication is that a component has no explicit way to create or destroy an
IP. A data packet is simply "created" when sent by a component and "destroyed"
when received.


#### Bounded buffer in connections

Morrison connection buffer is not bounded. Practically, they are bounded by the
buffer size of a Unix pipe on the machine. In that sense, it does honor the
bounded buffer feature of cFBP so that processes do block, but the buffer size
is not configurable at the application level.

The benefit of configurable boundedness is for the network designer to set the
degree of coupling between processes depending on system resources. Morrison
targets modern server-grade machines (see the section "Goals and non-goals"
above) and assumes that the operating system is configured to optimally run the
software in question.

#### Tree structures

There are no trees. The benefit of tree structures in cFBP is to pass just the
handle instead of the content itself. In Morrison, no sharing is allowed
between processes as each of them is a Unix system process.

#### Scheduling rules

Scheduling rules in cFBP are largely ignored because much of the control at
that level is delegated to the operating system kernel.

## Personas

These personas are to be used when creating user stories so we know who the
feature is catered to.

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

## Component specification

Each component requires a manifest file so that Morrison knows how to deal with
it. In fact, only the manifest file is needed to source, build, and deploy a
component. This section is split into several sub-sections for ease of
consumption but they all fall in one manifest file in practice.

The manifest files are written in [YAML](http://yaml.org/) for its maturity,
human-friendliness, and support for comments.

### Sourcing

A component is built and deployed from some source. A component's sourcing
manifest specifies where and how to build the component.

```yaml
source:
  protocol: git | http
  url: <url to archive>
  format: git | tar | tgz | zip
  working-directory: <path to a sub directory within the archive>
  build: <command to run to build>
  checks: <list of paths to scripts that check for the expected libraries>
  deploy: <list of files relative to the working directory to deploy after build>
```

Note that if any of the `build` command or the `check` scripts return a
non-zero status code, the build and deployment process would abort.

#### Checks

The `checks` section is critical. In an ideal world where every component runs
code inside its own boundaries, everything is rosy. In practice, components
most likely share libraries installed on the system, or call a command
available.

Checks ensure the correct libraries and commands are available as expected by a
component. In addition, if two components in a network use the same system
library/command but expect two different "versions", Morrison would not compile
the network.

The question becomes: how does Morrison know which version does each
conflicting component need? The answer is: it doesn't. There is no universal
way to track version. Some prefer hashes; some prefer semantic versioning; and
some prefer proprietary conventions. Worse yet, even in a single formalized
versioning scheme, say semantic versioning, what constitutes as a
backward-compatible version is not universally practiced or even agreed upon.

Morrison does not care about the versioning of the component because the
assumption is meaningless given the current practice on versioning. Instead,
Morrison depends on the component developer to specify how to check whether a
system library is what the component needs. After all, the component developer
is the only one who knows everything that the component uses.

### Inter-component communication

Just like web services must communicate with each other with HTTP connections
in a RESTful architecture, a component in FBP may only communicate with another
component with an FBP connection. A connection attaches to a component's port
on each of its two ends.

A connection is a stream. Just like there is a stream of messages in a
WebSocket connection over TCP, an FBP connection is a stream of Information
Packets, or IPs. Unlike a WebSocket connection, however, an FBP connection is
uni-directional.

Each component must define its ports. Like a TCP port, all data going through a
connection must pass through a designated port. Each FBP port must be
designated as an input port or an output port when the component is developed;
in contrast, a TCP port can be used to send and to receive.

In cFBP, IPs are explicitly created or destroyed by a component. In Morrison,
there is an open-world assumption that components are not expected to "know"
that they are in the Morrison world. Coupled with that all data transmitted
across the network are copied, this assumption leads to the design choice for
Morrison implicit create and destroy IPs on behalf of the component.

For Morrison to manage the IPs, it needs to understand the language which a
particular component speaks, so it requires the component to specify how it
sends and receives its data. It requires a `ports` section in the component
manifest.

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
      # CSV delimitering
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
      # CSV without bracket, i.e. a single-line CSV
      close-packet: [44] # Comma
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
  null-terminated) and produces string length. The marker would be the null
  character and it does not care about grouping.
- `flat`: The stream consists of packets of exactly ONE level. Every
  time a packet arrives that is NOT in a bracket already, it automatically
  opens a new bracket. An example is CSV. Each line is considered a group and
  no data may be outside of a group.
- `hierarchical`: This enables the full power of FBP. A stream
  consists of packets and brackets of more packets. Examples include
  transmitting hierarchical data structures like JSON and XML.

Each of the delimiter definitions is a list of bytes in decimal. At compile
time, Morrison matches the delimiter specification of the two ports in each 
connection. If they do not match, Morrison would insert an adapter to make sure
the delimiters agree.

Note that there are some delimitering structures that cannot be expressed with
this specification. For instance, proper CSV cannot be expressed as it allows
escaping delimiter characters by quoting a field. It is not the job of Morrison
to provide a way to automagically convert every format to every other format.
It provides these delimitering options to adhere to the FBP concept of an IP.

There is a `close-packet` but not a `open-packet`. Morrison assumes that all data
in a connection to be well-formed. And so once a packet has closed, a bracket
has closed, or the connection has just been opened, it assumes that the
upcoming data is part of a packet.

Input and output ports have distinct namespaces, and port names may contain
alphanumeric characters, underscores, and dashes. Morrison compiles ports into
integer values (just Unix file descriptors) for execution.

### Elementary component specification

We have talked about specifying to Morrison how to fetch the component and what
ports the component expects. For elementary components, Morrison needs four
things:

1. How to run the program inside a component?
2. What environment variables does the program expect?
3. What parameters does it expect?
4. What I/O streams does it expect?

#### The specification

```yaml
elementary:
  path: <path to program>
  environment-variables: <an associative array of case insensitive names to case sensitive names>
  parameters: <an array of case insensitive names>
  input-streams: <an array of case insensitive names>
  output-streams: <an array of case insensitive names>
```

In the environment variables attribute, the keys are case insensitive just like
parameters and streams, but the values are case sensitive so that the wrapper
can correctly specify the environment variables that the underlying program
expects.

`parameters`, `input-streams`, and `output-streams` must be an ordered array of
names because their orders are significant with Unix pipes.

### Composite component specification

If the component is a network, Morrison needs two things:

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
        path: <path to a component manifest file on the local filesystem>
        name: <a component name in the registry>
        url: <URL to a private component manifest>
      input:
        <name of one input port>:
          connected-process: <name of the connected process> | *
          connected-port: <name of the connected port> | *
        <... more input port definitions ...>
      output:
        <... more output port definitions ...>
    <... more process definitions ...>
```

We use the term "processes" to refer to instances of components. As a network
may contain the same component used in different ways, each of those component
instances is a process.

The name of a process in this network (i.e. the key of the `processes`
associative array) is an arbitrary name for this particular instance. It is
required so that we can specify to which process a port is connected.

Set `connected-process` to `*` to connect to network's own ports.
`connected-port` may be set to `*` for an automatic port.

## Special constructs

Some FBP constructs are crucial, yet there is no equivalent mapping with Unix
pipes. It is therefore necessary for the program to "know" that it is a
Morrison component to be able to use these constructs.

### Array ports

Array ports allow a process to selectively receive IPs from a number of
"sub-ports" in a single port. A Unix program, however, cannot separate out data
once it merges into a single stream accessible via a file descriptor.

In Morrison, a component may use array ports by reading the environment
variable `MORRISON_PORT_MAP_PATH`. It is the path to a file that contains port
mapping for ports.

#### Map file protocol

Each map file is tab-separated values of the following format:

```
IN | OUT  <port name>   <list of file descriptors separated by comma>
```

Note that the spaces above should be a tab in a real file.

An example would be:

```
IN  IN  0
IN  ArrayPort-1  3,5,6,7
OUT OUT 4
IN  ArrayPort-2  8,9,10
OUT NormalPort   4
```

A program can then read from this file and loop through the list to selectively
read from a sub-port.

## Glossary

Morrison tries to adhere to cFBP as closely as possible, so the vocabulary used
is almost identical as well.

For more FBP definitions, see the [FBP
Glossary](http://www.jpaulmorrison.com/fbp/gloss.htm).

### Program

In the context of Morrison, a "program" is Unix program that runs "inside" a
component. It is not necessarily aware that it is running inside the Morrison
world. A wrapper is applied around a program to connect the program to the
Morrison world.

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
and has a lifetime of its own. In Morrison, an IP does not have a lifetime of
its own in the sense that it is automatically created and destroyed upon
sending/receipt.

### Network

A network of components connected together to run some logic and honors a
number of in-ports and out-ports. A network is also a component.

### Subnet

A network. The term is used to distinguish it being part of a larger network.

### Elementary component

A component that is a wrapped program. i.e. not a network.

### Composite component

A network. The term is used to distinguish between components that are wrapped
programs and composite components that are networks. Also simply referred to
as a "composite".

### Substream sensitivitiy

A network designer may set a subnet as "substream sensitive" so that a
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
available for each component. An automatic port is used to transmit signals of
shutting down or delayed start of a process.

## References

1. Morrison, J. Paul (2011-02-26). Flow-Based Programming - 2nd Edition (p. 30)
2. Morrison, J. Paul (2011-02-26). Flow-Based Programming - 2nd Edition (p. 268)
