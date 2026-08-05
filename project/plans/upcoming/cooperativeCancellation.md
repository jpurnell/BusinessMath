There's no async version. The CalculationCache's InflightEntry issue isn't actually a memory leak since
  the calculation doesn't throw. Let me focus on the StreamingComposition detached tasks issue instead,
  which is more critical.

  Looking at the StreamingComposition code, there's a Task { @Sendable in ... } that runs detached without
  any way to cancel it. This task will continue running even if the consumer stops iterating. I need to:

  1. Store the task handle
  2. Add cancellation checking in the loops
  3. Cancel the task when the iterator is no longer needed

  Let me read more of the StreamingComposition to understand the full context.

⏺ The CalculationCache issue isn't critical since calculation() doesn't throw. Let me focus on the
  StreamingComposition detached task issue:

⏺ Read(/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMat
      h/Streaming/StreamingComposition.swift · lines 235-309)

  I see the issue now. The Task { @Sendable in ... } is started in the init of the Iterator but there's no
  way to cancel it. When the consumer stops iterating, the task continues running.

  The fix requires:
  1. Storing the Task handle
  2. Adding cancellation checks in the while loops
  3. Adding a way to cancel the task when needed

  However, since this is a struct, we can't easily add a deinit. The pattern used here (AsyncStream with
  detached Task) is a common Swift async pattern, but it does have the lifecycle issue.

  One solution is to check Task.isCancelled in the while loops. But that only helps if the outer task is
  cancelled - it doesn't help if the consumer just stops iterating.

  The AsyncStream does have a termination handler that could be used to cancel the task. Let me modify this
   to use the termination handler pattern:

  Actually, looking at this more carefully, the issue is that:
  1. The Task runs indefinitely consuming both streams
  2. If the consumer stops calling next(), the task keeps running
  3. The AsyncStream's values pile up (or get dropped depending on buffering policy)

  A proper fix would require restructuring to use cooperative cancellation. For now, let me add
  Task.isCancelled checks at minimum, which will help if the consumer's task is cancelled.
