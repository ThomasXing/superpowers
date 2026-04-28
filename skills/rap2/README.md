# RAP2 Skill

RAP2 接口文档管理平台 Skill，支持接口查询、代码生成、Java Bean 转 RAP2 JSON。

## 功能特性

### 🔍 接口查询
- 组织/仓库/模块/接口/属性完整 CRUD
- 支持 Mock 数据获取

### 🛠️ 代码生成
| 类型 | 说明 |
|------|------|
| axios | TypeScript + axios 调用代码 |
| miniprogram | 微信小程序 wx.request 代码 |
| flutter | Dart + Dio 调用代码 |

### 🔄 数据转换
- Java Bean → RAP2 JSON 格式
- 支持泛型、注释提取
- 批量目录转换

## 安装

Skill 已安装到 `~/.qoder/skills/rap2/`

## 使用方法

### 1. 接口查询

```
帮我查询 RAP2 中仓库 ID 为 123 的所有接口
```

### 2. 代码生成

**生成 axios 代码：**
```bash
node ~/.qoder/skills/rap2/scripts/generate-code.js http://localhost:38080 <interface-id> axios
```

**生成小程序代码：**
```bash
node ~/.qoder/skills/rap2/scripts/generate-code.js http://localhost:38080 <interface-id> miniprogram
```

**生成 Flutter 代码：**
```bash
node ~/.qoder/skills/rap2/scripts/generate-code.js http://localhost:38080 <interface-id> flutter
```

### 3. Java Bean 转换

**转换单个文件：**
```bash
node ~/.qoder/skills/rap2/scripts/java-to-rap2.js UserDTO.java
```

**转换整个目录：**
```bash
node ~/.qoder/skills/rap2/scripts/java-to-rap2.js ./dto/ ./output.json
```

## API 端点

### 认证
- `POST /account/login` - 登录
- `GET /account/info` - 当前用户信息

### 组织
- `GET /organization/list` - 组织列表
- `GET /organization/get?id={id}` - 组织详情

### 仓库
- `GET /repository/list` - 仓库列表
- `GET /repository/get?id={id}` - 仓库详情

### 模块
- `GET /module/list?repositoryId={id}` - 模块列表
- `GET /module/get?id={id}` - 模块详情

### 接口
- `GET /interface/list?moduleId={id}` - 接口列表
- `GET /interface/get?id={id}` - 接口详情
- `POST /interface/create` - 创建接口
- `POST /interface/update` - 更新接口
- `POST /interface/delete` - 删除接口

### Mock
- `GET /mock/{repositoryId}/{url}` - 获取 Mock 数据

## 类型映射

| Java 类型 | RAP2 类型 | TypeScript | Dart |
|-----------|-----------|------------|------|
| String | String | string | String |
| Integer/int | Number | number | double |
| Long/long | Number | number | double |
| Boolean/boolean | Boolean | boolean | bool |
| Date | String | string | String |
| List/Array | Array | any[] | List |
| Map/Object | Object | Record | Map |

## 文件结构

```
~/.qoder/skills/rap2/
├── SKILL.md              # 主要技能文档
├── examples.md           # 使用示例
├── reference.md          # API 参考
└── scripts/
    ├── java-to-rap2.js   # Java Bean 转换工具
    └── generate-code.js  # 代码生成工具
```

## 示例

### 示例 1：生成 axios 调用代码

输入接口：
```json
{
  "name": "getUserInfo",
  "url": "/api/user/info",
  "method": "GET",
  "requestProperties": [
    { "name": "userId", "type": "Number" }
  ],
  "responseProperties": [
    { "name": "id", "type": "Number" },
    { "name": "username", "type": "String" }
  ]
}
```

输出代码：
```typescript
/**
 * getUserInfo
 * @url /api/user/info
 * @method GET
 */
export function getUserInfo(userId: number) {
  return request.get('/api/user/info', {
    params: { userId }
  });
}

export interface GetUserInfoResponse {
  id: number;
  username: string;
}
```

### 示例 2：Java Bean 转换

输入：
```java
public class UserDTO {
    private Long id;
    private String username;
    private List<String> tags;
}
```

输出：
```json
{
  "name": "UserDTO",
  "properties": [
    { "name": "id", "type": "Number" },
    { "name": "username", "type": "String" },
    { "name": "tags", "type": "Array" }
  ]
}
```

## 相关资源

- [RAP2-DELOS 后端仓库](https://github.com/thx/rap2-delos)
- [RAP2-DOLORES 前端仓库](https://github.com/thx/rap2-dolores)

## License

MIT
