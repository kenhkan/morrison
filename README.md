# Morrison

Morrison is an FBP toolchain built on the ideas of [classical Flow-Based
Programming](http://www.jpaulmorrison.com/fbp/). It is designed to run a
network (i.e. a program in FBP) on a single Unix-like machine. It is a
toolchain in the sense that it:

- allows different sourcing protocols like git and HTTP to be used
  when fetching the source of components;
- enforces a component's ports and their types (a.k.a. business data
  types/objects);
- provides wrappers and adapters for executables not written with Morrison in
  mind to interact in a network;
- compiles network specification files into bash executable;
- links the different components that may have the same names
  without conflicts while avoids employing a "sub-dependency" strategy like
  what Node.js' npm does; and
- exposes a frontend UI that allows inspection of the network in real-time.
  i.e. A manager can see IPs traveling through the network while it is running.

If you are only interested in how to create components (both elementary and
composite), go straight to the [Component
specification](#component-specification) section.

## Philosophy

### Goals and non-goals

Morrison is not language-specific or even FBP-specific. If an executable runs
on a Unix-like machine, it is qualified as a Morrison component. The executable
may not even be aware that it is running as a component. This implies that one
component may be in Ruby while another in Rust; and that there is no SDK for
the executable to be compiled with.

It targets software designed to run in a modern server-side Unix environment.
It does not aim to run in the browser, on Windows, or on embedded hardware.
Frontend FBP (like a GUI) is out of scope. However, a frontend GUI to the
backend application is part of what Morrison is about. The biggest benefit of
FBP is to enable all stakeholders on a software project to participate in the
process of designing a piece of software.

In addition, Morrison is supposed to be an end-to-end toolchain to package,
build, deploy, run, AND monitor an FBP program. The program in the "backend"
emits IP (packet) and debugging information so that the frontend can show the
application running in real-time.

It has a single machine assumption. Parallelism is a difficult topic and is
best tackled at a different level on top of Morrison. Morrison is only
concerned with coordinating interdependent processes on a single machine.

### Differences from classical FBP (cFBP)

Morrison is conceptually cFBP but diverges from some of its rules highlighted
in the sub-sections below.

Note that despite the following differences, the two major constraints of FBP,
the flow constraint and the order-preserving constraint, [1] are enforced for
this to work as an FBP implementation.

Two of the three legs of FBP [2] also hold for Morrison:

* True: asynchronous processes
* False: data packets (IPs) with a lifetime of their own
* True: external definition of connections

#### Data packets (IPs) with a lifetime of their own

Enforcing IPs with their own lifetime offers a guarantee that a single IP is
not simultaneously used in two processes. This guarantee is rendered
meaningless in Morrison as it maps an FBP process to a Unix system process and
an FBP connection to a Unix pipe. Because of this system-level isolation,
unlike traditional cFBP implementations, the content, rather than the "handle",
of an IP is copied.

The implication is that a component has no formal way to create or destroy an
IP. A data packet is simply "destroyed" when received by a component and
"created" when sent.

#### Bounded buffer in connections

Connection buffer is not bounded. Practically, they are bounded by the allowed
size of a Unix pipe on the machine. In a sense, it does honor the bounded
buffer feature of cFBP, but the buffer size is not configurable at the
application level.

The benefit of configurable boundedness is for the network designer to set the
degree of coupling between processes depending on system resources. Morrison
targets modern server-side environment (see the section "Goals and non-goals"
above) and assumes that the operating system is configured to optimally run the
software in question.

#### Tree structures

There are no trees. The benefit of tree structures in cFBP is to pass just the
handle instead of the content itself. In Morrison, no sharing is allowed
between processes as each of them is a Unix system process. The cost of
serializing to allow for tree structures outstrips the benefits.

#### Scheduling rules

Scheduling rules in cFBP are largely ignored because much of the control at
that level is delegated to the operating system kernel.

#### Array ports

Array ports are not present in Morrison as this requires the component to be
able to select from which sub-port to receive. There is no equivalent concept
in Unix pipes and thus it violates the requirement that the executable inside a
component may not know that it's interacting in an FBP network.

## Personas

These personas are to be used when creating user stories so we know who the
feature is catered to.

### Matt

Matt is obsessed with performance and simplicity. His solutions are not
intuitive to most so they are difficult to maintain, but his creations are
usually the most innovative solutions to seemingly impossible problems.

### Mike

Mike is a frontend developer who is fanatical about beautiful and intuitive
design, regardless of how much work is involved. Perfection is a requirement.
His obsession often leads to some of the most stunning user interfaces.

### Raymond

Just a genius developer. Everyone knows that if she needs a hard problem
solved, Raymond is the person to ask. Given a problem, with somewhat (i.e. not
perfectly) clear requirements, Raymond can consistently deliver unexpected
results.

### Ryan

Ryan is a manager who is interested in technology but does not code. He learns
how to code on his own to get some understanding of what he manages and
delivers but nonetheless remains largely outside of the development realm. It
would delight him if there is a way he can be closer to his software's
development without needing to be a software engineer.

### Ken

A software engineer who just wants to get stuff done and doesn't want to worry
about maintenance. Managed service in the cloud is the best thing since sliced
bread.

## Component specification

Each component requires a manifest file so that Morrison knows how to deal with
it. This section is split into several sections for ease of consumption but
they all fall in one manifest file in practice.

The format of the manifest file is [YAML](http://yaml.org/) for its maturity,
human-friendliness, and support for comments.

### Sourcing

A component is built and deployed from some source. A component's sourcing
manifest specifies where and how to build the component.

```yaml
source:
  protocol: git|http
  url: <url to archive>
  format: git|tar|tgz|zip
  working directory: <path to a sub directory in the archive to build from>
  build: <command to run to build>
  check: <list of paths to scripts that check for the expected libraries>
  deploy: <list of files relative to the working directory to deploy after build>
```

Note that if any of the `build` command or the `check` scripts return a
non-zero status code, the build and deployment process would abort.

#### Checks

The `check` section is critical. In an ideal world where every component runs
code inside its own boundaries, everything is rosy. In practice, a component
most likely uses a library installed on the system on which it runs, or it
calls a command available.

Checks are specified to ensure that these libraries and commands are available
and are the correct ones as expected by a component. In addition, if two
components in a network use the same system library/command but expect two
different versions, Morrison would not compile the network.

The question becomes: how does Morrison know which version does each
conflicting component need? The answer is: it doesn't. There is no universal
way to track version. Some prefer hashes; some prefer semantic versioning; and
some prefer proprietary protocols. Worse yet, even in a single formalized
versioning scheme, say semantic versioning, what constitutes as a
backward-compatible version is not universally practiced or even agreed upon.

Morrison does not care about the versioning of the component because the
assumption is meaningless given the current practice on versioning. Instead,
Morrison depends on the component developer to specify how to check whether a
system library is what the component needs. After all, the component developer
knows everything that the component uses.

This also prevents two components using the same library but expecting two
versions. If the component developer of each conflicting components is diligent
in their tests, the conflict would be raised the network would fail to start.

### Inter-component communication

Just like services communicate with each other with HTTP connections in a
RESTful architecture, a component in FBP may only communicate with another
component with a connection. A connection attaches to a component's port on
each of its two ends.

A connection is a stream. Just like there is a stream of messages in a
WebSocket connection over TCP, an FBP connection is a stream of Information
Packets, or IPs. Unlike a WebSocket connection, however, an FBP connection is
uni-directional.

Each component must define its ports. Like a TCP port, all data going through a
connection must pass through a designated port. Each FBP port must be
designated as an input port or an output port when the component is developed;
in contrast, a TCP port can be used by any program at runtime.

In cFBP, IPs are explicitly created or destroyed by a component. In Morrison,
there is an open-world assumption that components are not expected to "know"
that they are in the Morrison world. Coupled with that all data transmitted
across the network are copied, this assumption leads to the design choice for
Morrison implicit create and destroy IPs on behalf of the component.

For Morrison to manage the IPs, it needs to understand the language that a
particular component speaks, so it requires the component to specify how it
sends its data. It requires a `ports` section in the component manifest!

```yaml
ports:
  input:
    one inport name:
      delimiter type: flat grouping
      # CSV delimitering
      close packet: [44] # Comma
      open bracket: []
      close bracket: [10] # Newline
    another inport name:
      delimiter type: hierarchical grouping
      # Parenthesized list
      close packet: [44] # Comma
      open bracket: [40] # Open parenthesis
      close bracket: [41] # Close parenthesis
    yet another inport name:
      delimiter type: no grouping
      # CSV without bracket, i.e. a single-line CSV
      close packet: [44] # Comma
      open bracket: []
      close bracket: []
  output:
    an outport name:
      delimiter type: flat grouping
      # Multi-byte delimiters
      close packet: [255, 12] # East Asian character comma in UTF-16
      open bracket: []
      close bracket: [48, 2] # East Asian character period in UTF-16
    another outport name:
      delimiter type: single packet
      # No delimitering, i.e. a single-packet connection
      close packet: []
      open bracket: []
      close bracket: []
```

Each port corresponds to a set of delimiter definitions: its delimitering type,
packet closing delimiter, bracket opening delimiter, and bracket closing
delimiter. The available delimitering types are:

- `single packet`: The entire stream consists of just one packet. An example
  would be a parser component parsing a stream of bytes from a file reader
  component. Normal Unix programs basically operate in this model; they read
  from or write to the stream however they want without clear logical
  demarcation of the transmitted bytes.
- `no grouping`: The stream consists of packets separated by some delimiter but
  there is only one level. It is useful for a component that only cares about
  receiving its data in chunks, each pair of which is demarcated by a common
  token. An example is a component that takes in C-style strings (i.e.
  null-terminated) and produces string length. The marker would be the null
  character while it does not care about grouping.
- `flat grouping`: The stream consists of packets of exactly ONE level. Every
  time a packet arrives that is NOT in a bracket already, it automatically
  opens a new bracket. An example is CSV. Each line is considered a group and
  no data may be outside of a group.
- `hierarchical grouping`: This enables the full power of FBP. A stream
  consists of packets and brackets of more packets or more brakcets of packets.
  Examples include transmitting hierarchical data structures like JSON and XML.

Each of the delimiter definitions is a list of bytes in decimal. At compile
time, Morrison matches the delimiter specification of the two ports in each 
connection. If they do not match, Morrison would insert an adapter to make sure
the delimiters agree.

Note that the are some delimitering structures that cannot be expressed with
this specification. For instance, full-fledged CSV cannot be expressed as it
allows escaping delimiter characters by quoting a field. It is not the job of
Morrison to provide a way to automagically convert every format to every other
format. It provides these delimitering options to ease integration as long as
the components delimit their input/output unambiguously.

There is a `close packet` but not a `open packet`. Morrison assumes that all data
in a connection to be well-formed. And so once a packet has closed, a bracket
has closed, or the connection has just been opened, it assumes that the
upcoming data is part of a packet.

Input and output ports have distinct namespaces, and there is no restriction on
the port name; it may be "normal name", "cAmElCaSe", or even contain symbols!
Morrison compiles ports into numeric values (just Unix file descriptors) for
execution.

### Elementary component specification

We have talked about specifying to Morrison how to fetch the component and what
ports does the component expect. For elementary components, Morrison needs four
things:

1. How to run the program that runs inside the component?
2. What environment variables does the program expect?
3. What parameters does it expect?
4. What I/O streams does it expect?

#### The specification

```yaml
elementary:
  path: <path to program>
  environment variables: <an associative array of case insensitive names to case sensitive names>
  parameters: <an array of case insensitive names>
  input streams: <an array of case insensitive names>
  output streams: <an array of case insensitive names>
```

In the environment variables attribute, the keys are case insensitive just like
parameters and streams, but the values are case sensitive so that the wrapper
can correctly specify the environment variables that the underlying program
expects.

### Composite component specification

If the component is a network, Morrison needs three things:

1. What sub-components are used?
2. Which ports of each sub-component is used and where are they attached to?
3. Coordinates of each sub-component relative to other sub-components so that
   they can be shown on a page as a network.

#### The specification

```yaml
composite:
  processes:
    <name of one process in this network>:
      source:
        type: local|registry|private
        path: <path to a component manifest on the local filesystem>
        name: <a component name in the registry>
        url: <URL to a private component manifest>
      coordinates:
        x: <x coordinate of the component in this network>
        y: <y coordinate of the component in this network>
      input:
        <name of one input port>:
          connected process: <name of the connected process>
          connected port: <name of connected port>
        <... more input port definitions ...>
      output:
        <... more output port definitions ...>
    <... more component definitions ...>
```

We use the term "processes" to refer to instances of components. As a network
may contain the same component used in different ways, each of those component
instances is a process.

The name of a process in this network (i.e. the key of the `processes`
associative array) is an arbitrary name for this particular instance. It is
required so that we can specify to which process a port is connected.

## Glossary

Morrison tries to adhere to cFBP as closely as possible, so the vocabulary used
is almost identical as well.

For more FBP definitions, see the [FBP
Glossary](http://www.jpaulmorrison.com/fbp/gloss.htm).

###  Component

A black box that runs some logic and honors a number of in-ports and out-ports.
The only way to communicate with the internal logic in a network is through the
ports.

### Port

An abstraction that takes some input or some output. Conceptually similar to
TCP ports, except that FBP ports are by name.

### Connection

Two ports are connected by a connection.

### IP

Information Packet: A unit of datum that gets transmitted over a connection at
a time and has a lifetime of its own.

### Network

A network of components connected together to run some logic and honors a
number of in-ports and out-ports. A network is also a component.

### Subnet

A network. The term is used to distinguish it being part of a larger network.

### Elementary component

A component that is not a network.

### Composite component

A network. The term is used to distinguish between elementary components that
are code and composite components that are networks.  Also simply referred to
as a "composite".

### Substream sensitivitiy

A network designer may set a port as "substream sensitive" so that a substream
going through that port is treated as a stream.  That is, when there is a
closing bracket coming from "outside" of the network, the stream is closed
"inside" the network.

### Array port

An array port is a normal port but supports multiple incoming connections (for
in-ports) or multiple outgoing connections (for out-ports).  Each sub-port in
an array port is a distinct and independent port from the other (sub-)ports.

### IIP

Initial information packet

### Automatic port

Ports that are not part of the component definition but are automatically
available for each component as part of the FBP convention. An automatic port
is used to transmit signals like shutting down or delayed start of a process.

## References

1. Morrison, J. Paul (2011-02-26). Flow-Based Programming - 2nd Edition (p. 30)
2. Morrison, J. Paul (2011-02-26). Flow-Based Programming - 2nd Edition (p. 268)
