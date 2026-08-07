#!/bin/bash
ERROR=0
check_file() {
    if [ -f "$1" ] && [ -s "$1" ]; then
        echo "✅ $1"
    else
        echo "❌ $1 (缺失或为空)"
        ERROR=1
    fi
}
echo "=== 项目完整性检查 ==="
check_file "settings.gradle.kts"
check_file "build.gradle.kts"
check_file "gradle.properties"
check_file "gradle/wrapper/gradle-wrapper.properties"
check_file "app/build.gradle.kts"
check_file "app/proguard-rules.pro"
check_file "app/src/main/AndroidManifest.xml"
check_file "app/src/main/res/values/colors.xml"
check_file "app/src/main/res/values/strings.xml"
check_file "app/src/main/res/values-zh/strings.xml"
check_file "app/src/main/res/values/themes.xml"
check_file "app/src/main/res/values-night/themes.xml"
check_file "app/src/main/res/drawable/ic_launcher_foreground.xml"
check_file "app/src/main/res/mipmap-anydpi-v24/ic_launcher.xml"
check_file "app/src/main/res/mipmap-anydpi-v24/ic_launcher_round.xml"
check_file "app/src/main/java/com/lingos/app/LINGOSApp.kt"
check_file "app/src/main/java/com/lingos/app/ui/splash/SplashActivity.kt"
check_file ".github/workflows/build.yml"
if [ $ERROR -eq 0 ]; then
    echo "✅ 所有文件完整"
else
    echo "❌ 存在缺失文件"
    exit 1
fi
