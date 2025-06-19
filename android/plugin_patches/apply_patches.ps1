$notificationsPluginPath = "C:\Users\User\AppData\Local\Pub\Cache\hosted\pub.dev\flutter_local_notifications-9.9.1\android\build.gradle"
$patchedFile = ".\plugin_patches\flutter_local_notifications\build.gradle"

Write-Host "Applying patch to flutter_local_notifications plugin..."
Copy-Item -Path $patchedFile -Destination $notificationsPluginPath -Force
Write-Host "Patch applied successfully!" 