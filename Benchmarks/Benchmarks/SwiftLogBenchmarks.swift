import Benchmark
import DisableTraceLogs_Benchmarks
import DisableDebugLogs_Benchmarks
import DisableInfoLogs_Benchmarks
import DisableNoticeLogs_Benchmarks
import DisableWarningLogs_Benchmarks
import DisableErrorLogs_Benchmarks
import DisableCriticalLogs_Benchmarks
import NoTraits_Benchmarks

let benchmarks: @Sendable () -> Void = {
    NoTraits_Benchmarks.benchmarks()
    DisableTraceLogs_Benchmarks.benchmarks()
    DisableDebugLogs_Benchmarks.benchmarks()
    DisableInfoLogs_Benchmarks.benchmarks()
    DisableNoticeLogs_Benchmarks.benchmarks()
    DisableWarningLogs_Benchmarks.benchmarks()
    DisableErrorLogs_Benchmarks.benchmarks()
    DisableCriticalLogs_Benchmarks.benchmarks()
}
