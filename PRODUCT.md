# PhotoPainter Console

<!-- impeccable:product-schema 1 -->

## Platform

Native macOS desktop app, Apple Silicon, SwiftUI, macOS 14 minimum.

## Stack

Standalone SwiftUI repository. The app talks to the ai-quota-frame Go service over a filesystem-protected Unix socket. The service owns a single serialized queue for BLE and USB maintenance operations; the console never opens its own radio or serial connection.

## Purpose

Operate a PhotoPainter frame and inspect its full device state without shell commands or reading service logs.

## Surfaces

Overview; device and applications; connection and discovery; image push; application characteristic communication; Wi-Fi configuration; USB maintenance; diagnostics.

The console has no tutorial, architecture or "how it works" pages. Explanations and developer documentation belong in the esp32s3 docs site.

## Product rules

- Keep the established visual language: light blue canvas, restrained blue controls, SF typography, native macOS controls.
- Show only real data: backend capabilities, operation results and authenticated device observations.
- Keep these states visibly distinct: capability supported, transport actually used, local send progress, physical display completion, and the age of each observation.
- Destructive actions require explicit confirmation. Never repeat a mutation because its response was lost; read status instead.
- Never expose private environment configuration, credentials, service logs, or Flash/NVS backup contents.
- Keep Wi-Fi passwords out of process arguments; send them only over the Unix socket.
