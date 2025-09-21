# Password Policy and Security Testing Script for Windows 11
# Скрипт для тестирования парольной политики и безопасности на Windows 11
# ВНИМАНИЕ: Используйте только в учебных целях и контролируемой среде!

Write-Host "=== Windows 11 Password Policy and Security Testing ===" -ForegroundColor Yellow
Write-Host "ВНИМАНИЕ: Этот скрипт предназначен только для обучения!" -ForegroundColor Red
Write-Host "Убедитесь, что вы работаете в изолированной тестовой среде." -ForegroundColor Red
Write-Host ""

# Проверка административных прав
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Этот скрипт должен запускаться с административными правами!" -ForegroundColor Red
    Write-Host "Щелкните правой кнопкой мыши на PowerShell и выберите 'Запуск от имени администратора'" -ForegroundColor Yellow
    pause
    exit
}

Write-Host "1. Создание тестовых пользователей..." -ForegroundColor Green

# Создание пользователей
try {
    # Пользователь со слабым паролем
    $weakPassword = ConvertTo-SecureString "1234" -AsPlainText -Force
    New-LocalUser -Name "testuser1" -Password $weakPassword -Description "Test user with weak password" -PasswordNeverExpires:$false
    Add-LocalGroupMember -Group "Users" -Member "testuser1"
    Write-Host "Пользователь testuser1 создан со слабым паролем" -ForegroundColor Yellow
    
    # Пользователь с сильным паролем
    $strongPassword = ConvertTo-SecureString "Xr!92_aL#5nM" -AsPlainText -Force
    New-LocalUser -Name "testuser2" -Password $strongPassword -Description "Test user with strong password" -PasswordNeverExpires:$false
    Add-LocalGroupMember -Group "Users" -Member "testuser2"
    Write-Host "Пользователь testuser2 создан с сильным паролем" -ForegroundColor Green
} catch {
    Write-Host "Ошибка при создании пользователей: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "2. Настройка парольной политики через secedit..." -ForegroundColor Green

# Создание временного файла конфигурации безопасности
$securityTemplate = @"
[Unicode]
Unicode=yes
[Version]
signature="`$CHICAGO`$"
Revision=1
[System Access]
MinimumPasswordAge = 7
MaximumPasswordAge = 90
MinimumPasswordLength = 12
PasswordComplexity = 1
PasswordHistorySize = 5
LockoutBadCount = 5
ResetLockoutCount = 30
LockoutDuration = 30
RequireLogonToChangePassword = 0
ForceLogoffWhenHourExpire = 0
NewAdministratorName = 
NewGuestName = 
ClearTextPassword = 0
LSAAnonymousNameLookup = 0
EnableAdminAccount = 0
EnableGuestAccount = 0
"@

$tempSecFile = "$env:TEMP\security_config.inf"
$securityTemplate | Out-File -FilePath $tempSecFile -Encoding ASCII

# Применение политики безопасности
try {
    secedit /configure /db "$env:TEMP\security.sdb" /cfg $tempSecFile /areas SECURITYPOLICY
    Write-Host "Парольная политика обновлена успешно" -ForegroundColor Green
} catch {
    Write-Host "Ошибка при применении политики: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "3. Тестирование слабых паролей..." -ForegroundColor Green

# Попытка изменить пароль на слабый
Write-Host "Попытка изменить пароль testuser1 на '12345':"
try {
    $veryWeakPassword = ConvertTo-SecureString "12345" -AsPlainText -Force
    Set-LocalUser -Name "testuser1" -Password $veryWeakPassword
    Write-Host "ПРЕДУПРЕЖДЕНИЕ: Слабый пароль был принят!" -ForegroundColor Red
} catch {
    Write-Host "Слабый пароль отклонен системой (это хорошо!)" -ForegroundColor Green
    Write-Host "Ошибка: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "4. Экспорт хешей паролей (только для демонстрации)..." -ForegroundColor Green

# Создание скрипта для получения хешей (упрощенная версия)
$hashScript = @"
Write-Host "ВНИМАНИЕ: Этот раздел показывает концепцию получения хешей" -ForegroundColor Yellow
Write-Host "В реальной среде для этого используются специальные инструменты" -ForegroundColor Yellow
Write-Host ""
Write-Host "Для получения хешей в учебных целях можно использовать:"
Write-Host "1. Mimikatz (в контролируемой среде)"
Write-Host "2. PowerShell Empire modules"
Write-Host "3. Impacket secretsdump.py"
Write-Host ""
Write-Host "Пример команд Mimikatz:"
Write-Host "mimikatz # privilege::debug"
Write-Host "mimikatz # sekurlsa::logonpasswords"
Write-Host "mimikatz # lsadump::sam"
"@

Invoke-Expression $hashScript

Write-Host ""
Write-Host "5. Информация о Hashcat для тестирования..." -ForegroundColor Green

$hashcatInfo = @"
Для тестирования стойкости паролей с помощью Hashcat:

1. Установите Hashcat на Linux VM или WSL
2. Используйте следующие команды:

   # Для NTLM хешей Windows (тип -m 1000)
   hashcat -m 1000 -a 0 hashes.txt /usr/share/wordlists/rockyou.txt
   
   # Для более агрессивного тестирования (брute force)
   hashcat -m 1000 -a 3 hashes.txt ?a?a?a?a?a?a?a?a

3. Ожидаемые результаты:
   - Слабый пароль '1234' будет взломан за секунды
   - Сильный пароль 'Xr!92_aL#5nM' может потребовать годы или останется невзломанным

ВАЖНО: Используйте только на собственных системах или в учебной среде!
"@

Write-Host $hashcatInfo -ForegroundColor Cyan

Write-Host ""
Write-Host "6. Проверка текущей парольной политики..." -ForegroundColor Green

# Экспорт текущей политики для проверки
try {
    secedit /export /cfg "$env:TEMP\current_policy.inf"
    $policyContent = Get-Content "$env:TEMP\current_policy.inf"
    $passwordSettings = $policyContent | Where-Object { $_ -match "Password|Lockout" }
    
    Write-Host "Текущие настройки парольной политики:" -ForegroundColor Yellow
    $passwordSettings | ForEach-Object { Write-Host "  $_" }
} catch {
    Write-Host "Не удалось экспортировать текущую политику" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== РЕЗУЛЬТАТЫ ТЕСТИРОВАНИЯ WINDOWS ===" -ForegroundColor Green
Write-Host ""
Write-Host "ВЫВОДЫ:" -ForegroundColor Yellow
Write-Host "1. Парольная политика помогает предотвратить использование слабых паролей"
Write-Host "2. Сложные пароли значительно труднее взломать"
Write-Host "3. Регулярная смена паролей снижает риск компрометации"
Write-Host "4. Блокировка учетных записей предотвращает brute force атаки"
Write-Host ""
Write-Host "ОЧИСТКА:" -ForegroundColor Red
Write-Host "Не забудьте удалить тестовых пользователей:"
Write-Host "Remove-LocalUser -Name 'testuser1'"
Write-Host "Remove-LocalUser -Name 'testuser2'"
Write-Host ""

# Удаление временных файлов
Remove-Item -Path $tempSecFile -ErrorAction SilentlyContinue
Remove-Item -Path "$env:TEMP\security.sdb" -ErrorAction SilentlyContinue
Remove-Item -Path "$env:TEMP\current_policy.inf" -ErrorAction SilentlyContinue

Write-Host "Тестирование завершено!" -ForegroundColor Green
Write-Host "ПОМНИТЕ: Используйте эти знания только для защиты, а не для атак!" -ForegroundColor Red

# Пауза для чтения результатов
Read-Host "Нажмите Enter для завершения"
