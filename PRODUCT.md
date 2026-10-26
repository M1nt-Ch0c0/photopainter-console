# PhotoPainter Console

<!-- impeccable:product-schema 1 -->

## Platform

Native macOS desktop, Apple Silicon, SwiftUI. macOS 14 minimum.

## Stack

Standalone SwiftUI repository. A direct, filesystem-protected Unix socket connects to the existing Go service in ai-quota-frame. The service owns a single serialized queue for BLE and maintenance operations.

## Purpose

Operate the PhotoPainter and inspect all currently exposed device state without relying on shell commands or interpreting ordinary service logs.

## Current surfaces

Overview; device and applications; connection and discovery; local image push; application characteristic communication; Wi-Fi configuration; USB maintenance; diagnostics.

Architecture education, work-principles pages and code tutorials were explicitly removed at the user's request. Developer documentation belongs in the project Wiki.

## Product rules

- Preserve the established light blue canvas, restrained blue controls, SF typography and native macOS affordances.
- Render actual backend capabilities, operation results and authenticated device observations.
- Distinguish capability support, actual transport, local send progress, physical completion and observation age.
- Keep destructive actions explicit and confirmed. Never repeat a mutation merely because its response was lost.
- Never expose private environment configuration, credentials, ordinary source logs, or Flash/NVS backup contents.
- Keep Wi-Fi passwords out of process arguments; communicate through the Unix socket.
- Support operations through the backend queue; do not open a competing radio connection from the GUI.

## Evidence

The paired host implements ABI 2.2 single-owner CoC, and photoframe v20 has completed a physical refresh over CoC. Operation coverage is enumerated in README. The standalone 0.4.0 build is compiled locally; deployment evidence is maintained by the main project.
