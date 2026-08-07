// 根项目构建文件
// 插件版本统一在 settings.gradle.kts 的 pluginManagement 中管理
tasks.register("clean", Delete::class) {
    delete(rootProject.buildDir)
}