/home/runner/work/BusinessMath/BusinessMath/Tests/BusinessMathTests/Visualization Tests/CommandLineVisualizationTests.swift /home/runner/work/BusinessMath/BusinessMath/Tests/BusinessMathTests/Visualization Tests/TornadoDiagramVisualizationTests.swift -target x86_64-unknown-linux-gnu -disable-objc-interop -I /home/runner/work/BusinessMath/BusinessMath/.build/x86_64-unknown-linux-gnu/debug/Modules -enable-testing -g -debug-info-format=dwarf -dwarf-version=4 -module-cache-path /home/runner/work/BusinessMath/BusinessMath/.build/x86_64-unknown-linux-gnu/debug/ModuleCache -swift-version 5 -Onone -D SWIFT_PACKAGE -D DEBUG -enable-upcoming-feature StrictConcurrency -empty-abi-descriptor -resource-dir /opt/hostedtoolcache/swift-Ubuntu/6.0.3/x64/usr/lib/swift -enable-anonymous-context-mangled-names -file-compilation-dir /home/runner/work/BusinessMath/BusinessMath -Xcc -fmodule-map-file=/home/runner/work/BusinessMath/BusinessMath/.build/checkouts/swift-crypto/Sources/CCryptoBoringSSLShims/include/module.modulemap -Xcc -I -Xcc /home/runner/work/BusinessMath/BusinessMath/.build/checkouts/swift-crypto/Sources/CCryptoBoringSSLShims/include -Xcc -fmodule-map-file=/home/runner/work/BusinessMath/BusinessMath/.build/checkouts/swift-crypto/Sources/CCryptoBoringSSL/include/module.modulemap -Xcc -I -Xcc /home/runner/work/BusinessMath/BusinessMath/.build/checkouts/swift-crypto/Sources/CCryptoBoringSSL/include -Xcc -fmodule-map-file=/home/runner/work/BusinessMath/BusinessMath/.build/checkouts/swift-numerics/Sources/_NumericsShims/include/module.modulemap -Xcc -I -Xcc /home/runner/work/BusinessMath/BusinessMath/.build/checkouts/swift-numerics/Sources/_NumericsShims/include -Xcc -fPIC -Xcc -g -Xcc -fno-omit-frame-pointer -module-name BusinessMathTests -package-name businessmath -plugin-path /opt/hostedtoolcache/swift-Ubuntu/6.0.3/x64/usr/lib/swift/host/plugins -plugin-path /opt/hostedtoolcache/swift-Ubuntu/6.0.3/x64/usr/local/lib/swift/host/plugins -emit-module-doc-path /home/runner/work/BusinessMath/BusinessMath/.build/x86_64-unknown-linux-gnu/debug/Modules/BusinessMathTests.swiftdoc -emit-module-source-info-path /home/runner/work/BusinessMath/BusinessMath/.build/x86_64-unknown-linux-gnu/debug/Modules/BusinessMathTests.swiftsourceinfo -emit-dependencies-path /home/runner/work/BusinessMath/BusinessMath/.build/x86_64-unknown-linux-gnu/debug/BusinessMathTests.build/BusinessMathTests.emit-module.d -parse-as-library -o /home/runner/work/BusinessMath/BusinessMath/.build/x86_64-unknown-linux-gnu/debug/Modules/BusinessMathTests.swiftmodule
2026-02-24T18:44:01.8630284Z /home/runner/work/BusinessMath/BusinessMath/Tests/BusinessMathTests/Financial Ratios Tests/RatioConvenienceFunctionsTests.swift:522:5: error: unexpected ',' separator
2026-02-24T18:44:01.8632124Z  520 | 						incomeStatementRole: .costOfGoodsSold,
2026-02-24T18:44:01.8633211Z  521 | 						timeSeries: TimeSeries(periods: periods, values: [400_000, 440_000]),
2026-02-24T18:44:01.8633993Z  522 | 				)
2026-02-24T18:44:01.8634698Z      |     `- error: unexpected ',' separator
2026-02-24T18:44:01.8635509Z  523 | 
2026-02-24T18:44:01.8635797Z  524 | 				// Operating expenses
2026-02-24T18:44:01.8636058Z 
2026-02-24T18:44:01.8637074Z /home/runner/work/BusinessMath/BusinessMath/Tests/BusinessMathTests/Financial Ratios Tests/RatioConvenienceFunctionsTests.swift:530:5: error: unexpected ',' separator
2026-02-24T18:44:01.8638441Z  528 | 						incomeStatementRole: .operatingExpenseOther,
2026-02-24T18:44:01.8639136Z  529 | 						timeSeries: TimeSeries(periods: periods, values: [300_000, 330_000]),
2026-02-24T18:44:01.8640020Z  530 | 				)
2026-02-24T18:44:01.8640352Z      |     `- error: unexpected ',' separator
2026-02-24T18:44:01.8640763Z  531 | 
2026-02-24T18:44:01.8641028Z  532 | 				// Depreciation
2026-02-24T18:44:01.8641261Z 
...
2026-02-24T18:46:43.0373720Z ##[error]Process completed with exit code 1.
2026-02-24T18:46:43.0474754Z Post job cleanup.
2026-02-24T18:46:43.1412413Z [command]/usr/bin/git version
2026-02-24T18:46:43.1448686Z git version 2.52.0
2026-02-24T18:46:43.1493071Z Temporarily overriding HOME='/home/runner/work/_temp/31cf70ec-b46c-4048-b28e-ff4d90565090' before making global git config changes
2026-02-24T18:46:43.1494395Z Adding repository directory to the temporary git global config as a safe directory
2026-02-24T18:46:43.1507154Z [command]/usr/bin/git config --global --add safe.directory /home/runner/work/BusinessMath/BusinessMath
2026-02-24T18:46:43.1541695Z [command]/usr/bin/git config --local --name-only --get-regexp core\.sshCommand
2026-02-24T18:46:43.1573968Z [command]/usr/bin/git submodule foreach --recursive sh -c "git config --local --name-only --get-regexp 'core\.sshCommand' && git config --local --unset-all 'core.sshCommand' || :"
2026-02-24T18:46:43.1802516Z [command]/usr/bin/git config --local --name-only --get-regexp http\.https\:\/\/github\.com\/\.extraheader
2026-02-24T18:46:43.1823936Z http.https://github.com/.extraheader
2026-02-24T18:46:43.1836766Z [command]/usr/bin/git config --local --unset-all http.https://github.com/.extraheader
2026-02-24T18:46:43.1866513Z [command]/usr/bin/git submodule foreach --recursive sh -c "git config --local --name-only --get-regexp 'http\.https\:\/\/github\.com\/\.extraheader' && git config --local --unset-all 'http.https://github.com/.extraheader' || :"
2026-02-24T18:46:43.2085658Z [command]/usr/bin/git config --local --name-only --get-regexp ^includeIf\.gitdir:
2026-02-24T18:46:43.2116501Z [command]/usr/bin/git submodule foreach --recursive git config --local --show-origin --name-only --get-regexp remote.origin.url
2026-02-24T18:46:43.2451267Z Cleaning up orphan processes
