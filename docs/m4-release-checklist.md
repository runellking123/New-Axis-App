# M4 QA + Release Checklist

## Reliability
- [x] Local CI build succeeds (`scripts/ci_local.sh`)
- [x] GitHub iOS CI run succeeds on milestone branch
- [x] Calendar authorization status is refreshed before event reads
- [x] Notification scheduling/cancel paths are explicit and user-driven

## Accessibility
- [x] Primary command actions include explicit accessibility labels/hints
- [x] Priority completion controls expose clear voice labels
- [x] Tab bar includes explicit accessibility labels

## Performance
- [x] No blocking network calls added to main thread
- [x] Report generation uses bounded configurable windows (7/14/30 days)
- [x] Build remains green with existing package/toolchain setup

## Final Regression
- [x] Command Center loads day brief/weather/next event
- [x] Settings notification toggle schedules or cancels day brief
- [x] Balance report regenerates and updates timestamp/window
- [x] Branch pushed and CI green
