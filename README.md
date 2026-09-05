# HomeAssistant Ityxx hassio-addons

## 安装加载项
[![添加本加载项到我的家庭助理][repository-badge]][repository-url]
repository: https://github.com/shiqixixixi/hassio-addons





[repository-badge]: https://img.shields.io/badge/Add%20repository%20to%20my-Home%20Assistant-41BDF5?logo=home-assistant&style=for-the-badge
[repository-url]: https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https://github.com/shiqixixixi/hassio-addons

## 新增应用要求

本仓库的构建工作流（`.github/workflows/build-addon.yml`）会自动发现并构建所有应用，无需手动修改工作流配置。新增应用只需满足以下条件：

1. **目录结构**：在仓库根目录下创建应用目录，目录名即应用名
2. **配置文件**：在应用目录下放置 `config.yaml`，必须包含以下字段：
   - `image`：镜像地址，格式为 `ghcr.io/shiqixixixi/hassio-addons/{arch}-<slug>`（必须包含 `{arch}-` 前缀）
   - `version`：应用版本号（如 `"7.4"`、`"2.11.0"`）
   - `arch`：支持的架构列表（可选值：`amd64`、`aarch64`、`armv7`、`armhf`、`i386`）
   - `slug`：应用标识符
3. **Dockerfile**：在应用目录下放置 `Dockerfile`
4. **构建参数**（仅当 Dockerfile 使用 `ARG BUILD_FROM` 时）：在应用目录下放置 `build.yaml`，指定各架构的基础镜像：

   `build.yaml` 示例：
   ```yaml
   build_from:
     aarch64: "ghcr.io/hassio-addons/base:21.0.3"
     amd64: "ghcr.io/hassio-addons/base:21.0.3"
     armv7: "bestlibre/armhf-debian-base:stretch"
     armhf: "bestlibre/armhf-debian-base:stretch"
     i386: "i386/debian:stretch"
   ```

满足以上条件后，推送代码到 `main` 分支即可自动触发构建。构建完成后，镜像会发布到 GHCR（GitHub Container Registry），并自动设置为公开可见，同时保留最近 3 个版本。