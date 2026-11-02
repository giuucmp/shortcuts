import Foundation
var checks = 0
func XCTAssertTrue(_ value: Bool, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) { checks += 1; if !value { fputs("FAIL \(file):\(line) \(message)\n", stderr); exit(1) } }
func XCTAssertFalse(_ value: Bool, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) { XCTAssertTrue(!value, message, file: file, line: line) }
func XCTAssertEqual<T: Equatable>(_ a: T, _ b: T, file: StaticString = #filePath, line: UInt = #line) { XCTAssertTrue(a == b, "\(a) != \(b)", file: file, line: line) }
let t = CoreTests()
t.testAllModifiersAndSuperset(); t.testSystemIncludedAndAppsIsolated(); t.testOptionControlShiftAndFnCanStart(); t.testTypingCancelsAndDoesNotReopenUntilRelease(); t.testProgressiveModifierDoesNotRestartDelay(); t.testContextPreservedAndExactDuplicatesRemoved(); t.testAXModifiersAreNotNSEventFlags(); t.testStaleScanCannotReplaceCurrentApp()
print("PASS: \(checks) assertions")
do { try checkCatalog() } catch { fputs("FAIL catalog: \(error)\n",stderr); exit(1) }
do { try checkSafariDeveloper() } catch { fputs("FAIL Safari developer: \(error)\n",stderr); exit(1) }
do { try checkBindings() } catch { fputs("FAIL bindings: \(error)\n",stderr);exit(1) }
print("TOTAL PASS: \(checks) assertions")
do {try checkCustomImport()}catch{fputs("FAIL custom: \(error)\n",stderr);exit(1)}
do {try checkReviewRegressions()}catch{fputs("FAIL review: \(error)\n",stderr);exit(1)}
do {try checkCompactLayout()}catch{fputs("FAIL compact layout: \(error)\n",stderr);exit(1)}
checkHoldBehavior()
do {try checkGrouping()}catch{fputs("FAIL grouping: \(error)\n",stderr);exit(1)}
checkGroupReadingOrder()
do {try checkLearningPresentation();try checkPracticeSessions();try checkCustomization()}catch{fputs("FAIL learning: \(error)\n",stderr);exit(1)}
do {try checkAuditRegressions()}catch{fputs("FAIL audit: \(error)\n",stderr);exit(1)}
do {try checkContextualShortcuts()}catch{fputs("FAIL context: \(error)\n",stderr);exit(1)}
checkPracticeKeyboard()
do {try checkLocalization()}catch{fputs("FAIL localization: \(error)\n",stderr);exit(1)}
print("ALL CHECKS PASSED: \(checks)")
