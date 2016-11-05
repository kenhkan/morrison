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

```
source:
  protocol: git|http
  url: <url-to-archive>
  format: git|tar|tgz|zip
  # Current Working Directory
  cwd: <path-to-a-sub-directory-in-the-archive-to-build-from>
  build: <command-to-run-to-build>
  check:
    <path-to-a-required-library>: <path-to-a-script-to-check-the-library>
    <path-to-another-library>: <path-to-another-script>
    <path-to-a-command>: <path-to-yet-another-script-to-check-the-command>
  deploy:
    - list/of/files
    - and/directories/
    - relative/to/cwd/as/defined/above
    - to/deploy/after/build
    - wildcard/*/is/accepted
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

When there are components with conflicting required libraries, Morrison would
not compile a network if a check from one of the conflicting components return
a non-zero status code.

## Glossary

Morrison tries to adhere to cFBP as closely as possible, so the vocabulary used
is almost identical as well.

Component | A black box that runs some logic and honors a number of in-ports
and out-ports. The only way to communicate with the internal logic in a network
is through the ports.
Port | An abstraction that takes some input or some output. Conceptually
similar to TCP ports, except that FBP ports are by name.
Connection | Two ports are connected by a connection.
IP | Information Packet: A unit of datum that gets transmitted over a
connection at a time and has a lifetime of its own.
Network | A network of components connected together to run some logic and
honors a number of in-ports and out-ports. A network is also a component.
Subnet | A network. The term is used to distinguish it being part of a larger
network.
Elementary component | A component that is not a network.
Composite component | A network. The term is used to distinguish between
elementary components that are code and composite components that are networks.
Also simply referred to as a "composite".
Substream sensitivitiy | A network designer may set a port as "substream
sensitive" so that a substream going through that port is treated as a stream.
That is, when there is a closing bracket coming from "outside" of the network,
the stream is closed "inside" the network.
Array port | An array port is a normal port but supports multiple incoming
connections (for in-ports) or multiple outgoing connections (for out-ports).
Each sub-port in an array port is a distinct and independent port from the
other (sub-)ports.
IIP | Initial information packet
Automatic port | Ports that are not part of the component definition but are
automatically available for each component as part of the FBP convention. An
automatic port is used to transmit signals like shutting down or delayed start
of a process.

For more FBP definitions, see the [FBP
Glossary](http://www.jpaulmorrison.com/fbp/gloss.htm).

## References

1. Morrison, J. Paul (2011-02-26). Flow-Based Programming - 2nd Edition (p. 30)
2. Morrison, J. Paul (2011-02-26). Flow-Based Programming - 2nd Edition (p. 268)
