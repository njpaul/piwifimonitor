# PiWifiMonitor
Monitor your Wi-Fi connection and perform a controlled reset of your router and
modem.

## Motivation
When your Wi-Fi goes out, do you hate having to manually turn off both your
router and modem, wait a while, turn the modem on, wait some more, turn the
router on, wait some more, and then finally see if Wi-Fi was restored?

This project aims to automate all that nonsense.

Routers and modems occasionally need to be reset. For whatever reason, they
just stop working. This usually happens at inopportune times. Maybe you're
just settling in with dinner or a snack on the couch and suddenly your
favorite streaming service just stops. Maybe you wake up in the morning ask
your smart home device to start your day, and are greeted with a "cannot
connect to Internet" response.

Consumer-grade routers and modems have gotten pretty reliable over the years,
but none of them are perfect, and there are plenty of people out there with
older equipment that works just fine. Why upgrade if you don't really need to?

There are, of course, products out there that will turn off/on a plug when
your Wi-Fi goes out, but those typically let you control just a single outlet.
Other mid-range products let you control several outlets, but only give you
one control signal, so you can't stage the resets. It's cost-prohibitive for
the typical consumer to buy an expensive product just for the purpose of
saving a trip to router and modem. This is the gap PiWifiMonitor aims to fill.

## Description
This project makes use of a Raspberry Pi Zero W to provide a cost-effective
automated solution to resetting your modem and router when the Wi-Fi goes out.

What I wanted for myself was a four-outlet box, with two outlets "always on",
and two controlled independently by a Raspberry Pi's GPIOs.

### Requirements
- Raspberry Pi Zero W, with case and SD card
- Two-channel 5V relay module
- A 2-gang electrical box, with outlets and plate
- A power cable from a computer or power strip
- Small-gauge wire (22 AWG is what I used)
- Soldering gun and solder
- Outlet tester or multimeter

## Documentation
Documentation is a work in progress. It will be in a separate directory as
a series of guides for the build.

## Roadmap
- Roll over log file
- Push events to other processes via message queue
- Document the build process of both the outlet and the software
- Push the docker image to Docker Hub
- Setup as WAP to allow SSH into WAP (for maintenance), but not through router
- Web server on WAP for monitoring
- More advanced diagnostics, like checking latency, carrier status, and DNS resolution
- Hot-reload of configs
- Convert to POSIX shell script...maybe
- Make native package
- Learning mode