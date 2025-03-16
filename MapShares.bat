@ECHO OFF
setlocal enabledelayedexpansion 
:: Sets the value of file that we store the paths that will be mapped 
set "file=C:\tools\paths.txt"
set count=0

:: Algorithm that will take each path in the file variable and determine the drive letter that will be used when mapping the shared drive
:: Checks for available drives against array of letters. Once an available drive letter is found, net use maps the drive to the user's profile
for /F "tokens=*" %%i in ('Type "%file%"') do (
	set path=%%i
	set count=0
	for %%a in (z y x w v u t s r q p o n m l k j i h g f e) do (
		if !count! == 0 (
			if not exist %%a: (
				set count=1
				set drv=%%a:
				ECHO !drv! "!path!"
				c:\windows\SysWOW64\net use !drv! "!path!"
			)
		)
	)
)