@echo off
setlocal
rem Explorer-double-click launcher for scripts/run-ci-dotnet.sh. Resolves Git
rem Bash via Common-Automation's _find-bash.bat, then runs the script with
rem the engine pause suppressed (this .bat self-pauses below). With no
rem COMMON_DOTNET_TARGET_REPO the run targets this repo's own sample.
rem Common-Automation is expected as a sibling checkout under the same
rem parent directory.

call "%~dp0..\..\Common-Automation\scripts\_find-bash.bat" || exit /b 1

set COMMON_AUTOMATION_NO_PAUSE=1
"%BASH%" "%~dp0run-ci-dotnet.sh" %*
set rc=%errorlevel%
pause
exit /b %rc%
