local server_jar = vim.fn.stdpath "data"
  .. "/mason/packages/vscode-spring-boot-tools/extension/language-server/"
  .. "spring-boot-language-server-2.2.0-SNAPSHOT-exec.jar"

return {
  cmd = {
    "java",
    "-Xmx768m",
    "-Dsts.lsp.client=vscode",
    "-Dspring.main.web-application-type=NONE",
    "-Dspring.config.location=classpath:/application.properties",
    "-Djdk.util.zip.disableZip64ExtraFieldValidation=true",
    "-jar",
    server_jar,
  },
  filetypes = { "jproperties" },
  root_markers = { "pom.xml", "mvnw", "gradlew", "build.gradle", "build.gradle.kts", ".git" },
  get_language_id = function(_, _) return "spring-boot-properties" end,
  init_options = {
    enableJdtClasspath = false,
  },
  capabilities = {
    workspace = {
      executeCommand = { dynamicRegistration = true },
    },
  },
}
