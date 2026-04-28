# RAP2 Skill 使用示例

## 示例 1：查询接口并生成代码

### 场景
用户需要查询某个仓库的所有接口，并生成 axios 调用代码。

### 代码
```typescript
// 1. 登录获取 session
await fetch('/account/login', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ email: 'user@example.com', password: 'xxx' })
})

// 2. 获取仓库列表
const reposResponse = await fetch('/repository/list')
const repos = await reposResponse.json()

// 3. 选择仓库获取模块
const repoId = repos.data[0].id
const modulesResponse = await fetch(`/module/list?repositoryId=${repoId}`)
const modules = await modulesResponse.json()

// 4. 获取接口列表
const moduleId = modules.data[0].id
const interfacesResponse = await fetch(`/interface/list?moduleId=${moduleId}`)
const interfaces = await interfacesResponse.json()

// 5. 生成 axios 代码
interfaces.data.forEach(iface => {
  const code = generateAxiosCode(iface)
  console.log(code)
})
```

## 示例 2：批量转换 Java Bean

### 场景
用户有多个 Java DTO 类，需要批量转换为 RAP2 JSON。

### 代码
```typescript
const javaBeans = [
  `
  public class UserDTO {
      private Long id;
      private String username;
      private String email;
  }
  `,
  `
  public class OrderDTO {
      private Long orderId;
      private BigDecimal amount;
      private Integer status;
      private Date createTime;
  }
  `
]

const rap2Modules = javaBeans.map(bean => ({
  name: extractClassName(bean),
  description: '',
  interfaces: [{
    name: extractClassName(bean),
    url: '',
    method: 'GET',
    requestProperties: [],
    responseProperties: javaBeanToRap2Properties(bean)
  }]
}))

// 导出为 RAP2 导入格式
const exportData = {
  name: 'API Module',
  modules: rap2Modules
}

console.log(JSON.stringify(exportData, null, 2))
```

## 示例 3：生成小程序请求代码

### 场景
为微信小程序生成接口调用代码。

### 代码
```typescript
function generateMiniProgramCode(iface: Interface): string {
  const method = iface.method.toUpperCase()
  
  return `
/**
 * ${iface.name}
 * ${iface.description || ''}
 */
export function ${toCamelCase(iface.name)}(data = {}) {
  return new Promise((resolve, reject) => {
    wx.request({
      url: \`${getBaseUrl()}${iface.url}\`,
      method: '${method}',
      header: {
        'Content-Type': 'application/json'
      },
      ${method === 'GET' ? 'data: data' : 'data: JSON.stringify(data)'},
      success: (res) => {
        if (res.statusCode === 200) {
          resolve(res.data)
        } else {
          reject(res)
        }
      },
      fail: reject
    })
  })
}
`
}

// 使用示例
const iface = {
  name: 'getUserInfo',
  url: '/api/user/info',
  method: 'GET',
  description: '获取用户信息'
}

console.log(generateMiniProgramCode(iface))
```

### 输出
```typescript
/**
 * getUserInfo
 * 获取用户信息
 */
export function getUserInfo(data = {}) {
  return new Promise((resolve, reject) => {
    wx.request({
      url: `https://api.example.com/api/user/info`,
      method: 'GET',
      header: {
        'Content-Type': 'application/json'
      },
      data: data,
      success: (res) => {
        if (res.statusCode === 200) {
          resolve(res.data)
        } else {
          reject(res)
        }
      },
      fail: reject
    })
  })
}
```

## 示例 4：生成 Flutter 代码

### 场景
为 Flutter 应用生成接口调用代码。

### 代码
```typescript
function generateFlutterCode(iface: Interface): string {
  const className = toPascalCase(iface.name) + 'Request'
  
  return `
import 'package:dio/dio.dart';

class ${className} {
  final Dio _dio = Dio();
  
  /// ${iface.description || iface.name}
  Future<dynamic> call(${generateFlutterParams(iface)}) async {
    try {
      final response = await _dio.${iface.method.toLowerCase()}(
        '${iface.url}',
        ${iface.method.toLowerCase() === 'get' ? 'queryParameters: params' : 'data: body'},
      );
      return response.data;
    } catch (e) {
      throw Exception('Request failed: \$e');
    }
  }
}
`
}
```

## 示例 5：Mock 数据生成

### 场景
根据接口定义生成 Mock 数据。

### 代码
```typescript
function generateMockData(properties: Property[]): object {
  const mockData: Record<string, any> = {}
  
  properties.forEach(prop => {
    switch (prop.type) {
      case 'String':
        mockData[prop.name] = `@string(${prop.name})`
        break
      case 'Number':
        mockData[prop.name] = `@integer(1, 100)`
        break
      case 'Boolean':
        mockData[prop.name] = `@boolean()`
        break
      case 'Array':
        mockData[prop.name] = []
        break
      case 'Object':
        mockData[prop.name] = {}
        break
      default:
        mockData[prop.name] = null
    }
  })
  
  return mockData
}

// 使用示例
const properties = [
  { name: 'id', type: 'Number' },
  { name: 'username', type: 'String' },
  { name: 'isActive', type: 'Boolean' }
]

console.log(generateMockData(properties))
// 输出：
// {
//   id: '@integer(1, 100)',
//   username: '@string(username)',
//   isActive: '@boolean()'
// }
```
