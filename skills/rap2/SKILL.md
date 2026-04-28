---
name: rap2
description: RAP2 接口文档管理平台 Skill，支持接口查询、代码生成、Java Bean 转 RAP2 JSON。当需要查询 RAP2 接口文档、生成前端调用代码（axios/小程序/Flutter）、或需要将 Java Bean 转换为 RAP2 可导入的 JSON 时使用。
---

# RAP2 接口文档管理

## 概述

RAP2 (RESTful API Project) 是一个接口文档管理平台，用于管理 RESTful API 接口定义、Mock 数据和文档导出。

## 核心功能

1. **接口查询**：获取仓库、模块、接口、属性信息
2. **代码生成**：生成前端调用代码（axios/小程序/Flutter）
3. **数据转换**：Java Bean 转 RAP2 JSON 格式
4. **Mock 服务**：获取接口 Mock 数据

## API 端点

### 认证相关
- `POST /account/login` - 登录
- `GET /account/info` - 获取当前用户信息
- `GET /account/list` - 用户列表

### 组织管理
- `GET /organization/list` - 组织列表
- `GET /organization/owned` - 我拥有的组织
- `GET /organization/joined` - 我加入的组织
- `GET /organization/get?id={id}` - 组织详情

### 仓库管理
- `GET /repository/list` - 仓库列表
- `GET /repository/owned` - 我拥有的仓库
- `GET /repository/joined` - 我加入的仓库
- `GET /repository/get?id={id}` - 仓库详情

### 模块管理
- `GET /module/list?repositoryId={id}` - 模块列表
- `GET /module/get?id={id}` - 模块详情

### 接口管理
- `GET /interface/list?moduleId={id}` - 接口列表
- `GET /interface/get?id={id}` - 接口详情
- `POST /interface/create` - 创建接口
- `POST /interface/update` - 更新接口
- `POST /interface/delete` - 删除接口

### 属性管理
- `GET /property/list?interfaceId={id}` - 属性列表
- `GET /property/get?id={id}` - 属性详情

### Mock 服务
- `GET /mock/{repositoryId}/{url}` - 获取 Mock 数据

## 代码生成

### 生成 axios 调用代码

```typescript
function generateAxiosCode(iface: Interface): string {
  const method = iface.method.toLowerCase()
  const url = iface.url
  
  return `
// ${iface.name}
// ${iface.description || ''}
export function ${iface.name}(${generateParams(iface)}) {
  return request.${method}('${url}', {
    ${method === 'get' ? 'params' : 'data'}: ${generateDataParam(iface)}
  })
}
`
}
```

### 生成小程序调用代码

```typescript
function generateMiniProgramCode(iface: Interface): string {
  return `
// ${iface.name}
${iface.description || ''}
export function ${iface.name}(data) {
  return new Promise((resolve, reject) => {
    wx.request({
      url: '${iface.url}',
      method: '${iface.method}',
      data: data,
      success: resolve,
      fail: reject
    })
  })
}
`
}
```

## Java Bean 转 RAP2 JSON

将 Java Bean 转换为 RAP2 可导入的 JSON 格式：

```typescript
function javaBeanToRap2Json(javaCode: string): object {
  // 解析 Java 类定义
  const classMatch = javaCode.match(/class\s+(\w+)/)
  const className = classMatch ? classMatch[1] : 'Unknown'
  
  // 解析字段
  const fieldPattern = /(private|public)\s+(\w+(?:<[^>]+>)?)\s+(\w+);/g
  const properties = []
  let match
  
  while ((match = fieldPattern.exec(javaCode)) !== null) {
    const [, access, type, name] = match
    properties.push({
      name,
      type: javaTypeToRap2Type(type),
      description: ''
    })
  }
  
  return {
    name: className,
    properties
  }
}

function javaTypeToRap2Type(javaType: string): string {
  const typeMap: Record<string, string> = {
    'String': 'String',
    'Integer': 'Number',
    'int': 'Number',
    'Long': 'Number',
    'long': 'Number',
    'Double': 'Number',
    'double': 'Number',
    'Float': 'Number',
    'float': 'Number',
    'Boolean': 'Boolean',
    'boolean': 'Boolean',
    'Date': 'String',
    'List': 'Array',
    'Map': 'Object'
  }
  
  // 处理泛型
  if (javaType.includes('<')) {
    const baseType = javaType.split('<')[0]
    return typeMap[baseType] || 'Object'
  }
  
  return typeMap[javaType] || 'Object'
}
```

## 使用示例

### 查询接口文档

```typescript
// 1. 获取仓库列表
const repos = await fetch('/repository/list').then(r => r.json())

// 2. 获取模块列表
const modules = await fetch('/module/list?repositoryId=123').then(r => r.json())

// 3. 获取接口列表
const interfaces = await fetch('/interface/list?moduleId=456').then(r => r.json())

// 4. 获取接口详情
const iface = await fetch('/interface/get?id=789').then(r => r.json())
```

### 生成前端代码

```typescript
// 生成 axios 代码
const code = generateAxiosCode(iface)
console.log(code)

// 输出：
// export function getUserInfo(params) {
//   return request.get('/api/user/info', { params })
// }
```

### Java Bean 转换

```typescript
const javaCode = `
public class UserDTO {
    private Long id;
    private String username;
    private Integer age;
    private List<String> tags;
}
`

const rap2Json = javaBeanToRap2Json(javaCode)
console.log(JSON.stringify(rap2Json, null, 2))

// 输出：
// {
//   "name": "UserDTO",
//   "properties": [
//     { "name": "id", "type": "Number" },
//     { "name": "username", "type": "String" },
//     { "name": "age", "type": "Number" },
//     { "name": "tags", "type": "Array" }
//   ]
// }
```

## 数据类型映射

| Java 类型 | RAP2 类型 | 说明 |
|-----------|-----------|------|
| String | String | 字符串 |
| Integer/int | Number | 整数 |
| Long/long | Number | 长整数 |
| Double/double | Number | 浮点数 |
| Boolean/boolean | Boolean | 布尔值 |
| Date | String | 日期（字符串格式） |
| List/Array | Array | 数组 |
| Map/Object | Object | 对象 |
| 自定义类 | Object | 嵌套对象 |

## 最佳实践

1. **接口命名规范**：使用动词+名词，如 `getUserInfo`、`createOrder`
2. **字段注释**：为每个字段添加清晰的描述
3. **类型定义**：尽量使用具体类型而非 Object
4. **Mock 数据**：为接口提供有意义的 Mock 数据

## 相关资源

- RAP2 官方仓库：https://github.com/thx/rap2-delos
- RAP2 前端仓库：https://github.com/thx/rap2-dolores
