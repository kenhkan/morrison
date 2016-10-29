# Morrison

[![Stories in Ready](https://badge.waffle.io/kenhkan/morrison.png?label=ready&title=Ready)](http://waffle.io/kenhkan/morrison)

Morrison is an FBP toolchain built on the ideas of [classical Flow-Based
Programming](http://www.jpaulmorrison.com/fbp/). It is designed to run a subnet
(i.e. a program in FBP) on a single Unix-like machine. It is a toolchain in the
sense that it:

- allows different source transfer protocols like git, HTTP, and SSH to be used
  when fetching the source of components and subnets;
- enforces a component's ports and their types (a.k.a. business data
  types/objects) with a manifest format;
- provides wrappers for executables not written with Morrison in mind to
  interact in a subnet;
- compiles subnet specification files in an FBP DSL into bash executable;
- links the different components and subnets that may have the same names
  without conflicts while avoiding employing a "sub-dependency" strategy like
  what Node.js' npm does; and
- exposes a frontend UI that allows inspection of the subnet in real-time. i.e.
  A manager can see IPs traveling through the subnet while it is running.

## Philosophy

### Goals and non-goals

- This is intended to build and run backend programs in FBP. Frontend FBP is
  out of scope.
- However, a frontend UI to these backend programs is part of what Morrison is
  about, so that the biggest benefit, that everyone can participate in
  designing a piece of software, can be realized.
- Moreover, Morrison is supposed to be an end-to-end toolchain to package,
  build, deploy, AND monitor an FBP program. The program in the "backend" emits
  IP and debugging information so that the frontend can show the program
  running in real-time.
- Single machine assumption: parallelism is to best tackled at a different
  level. Morrison is only concerned with coordination in a single machine.

### Differences with classical FBP (cFBP)

Morrison is conceptually cFBP but violates some of its rules,
including, but not limited to:

- Buffers are not bounded. Practically, they are bounded by the size of UNIX
  pipes on the machine. In a way, it partially follows the bounded buffer
  feature of cFBP but the buffer size is not configurable at the application
  level.
- There are no trees. The benefit of tree structures in FBP is to pass just the
  handle instead of the data itself. In Morrison, each component is
  instantiated as a system process. No sharing is allowed. The benefit is
  rendered moot and the cost of serialization outstrips the benefits.
- Scheduling rules in cFBP are largely ignored because much of the control at
  that level is delegated to the nix kernel.

Note that despite the differences, the two major constraints of FBP, the flow
constraint and the order-preserving constraint, [1] are respected for this to
work as an FBP implementation.

As a reminder, the three legs of FBP [2] hold for Morrison:

* asynchronous processes
* data packets (IPs) with a lifetime of their own
* external definition of connections

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
delivers but nonetheless remains largely outside of the development of it. It
would delight him if there is a way he can contribute to the software's
development.

### Ken

A software engineer who just wants to get stuff done and doesn't want to worry
about maintaining anything. Managed service in the cloud is the best thing
since sliced bread.

## References

[1] Morrison, J. Paul  (2011-02-26). Flow-Based Programming - 2nd Edition (p. 30)
[2] Morrison, J. Paul  (2011-02-26). Flow-Based Programming - 2nd Edition (p. 268)
