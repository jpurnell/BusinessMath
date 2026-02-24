//
//  PlatformSupport.swift
//  BusinessMath
//
//  Created by Claude Code on 2025-02-24.
//

import Foundation

// MARK: - Cross-Platform Math Support

/// Cross-platform support for math functions and networking
///
/// This file provides unified imports for cross-platform testing:
/// - Math functions (pow, sqrt, erfc) via Darwin/Glibc
/// - Networking types (URLRequest, URLResponse, etc.) via FoundationNetworking on Linux
///
/// ## Platform Behavior
///
/// - **Apple Platforms**: Uses Darwin for math, Foundation for networking
/// - **Linux**: Uses Glibc for math, FoundationNetworking for networking
///
/// Simply import this file in test targets to ensure cross-platform compatibility.

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
