# detekt

## Metrics

* 89 number of properties

* 114 number of functions

* 58 number of classes

* 7 number of packages

* 12 number of kt files

## Complexity Report

* 1,812 lines of code (loc)

* 1,230 source lines of code (sloc)

* 955 logical lines of code (lloc)

* 325 comment lines of code (cloc)

* 203 cyclomatic complexity (mcc)

* 37 cognitive complexity

* 56 number of total code smells

* 26% comment source ratio

* 212 mcc per 1,000 lloc

* 58 code smells per 1,000 lloc

## Findings (56)

### complexity, LongMethod (1)

One method should have one responsibility. Long methods tend to handle many things at once. Prefer smaller methods to make them easier to understand.

[Documentation](https://detekt.dev/docs/rules/complexity#longmethod)

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/api/UserRoutes.kt:22:11
```
The function userRoutes is too long (90). The maximum length is 60.
```
```kotlin
19  * - ラムダレシーバーの型解決
20  * - 拡張関数（Routing）の参照
21  */
22 fun Route.userRoutes(userService: UserService) {
!!           ^ error
23     route("/users") {
24         // ユーザー一覧取得
25         get {

```

### complexity, TooManyFunctions (2)

Too many functions inside a/an file/class/object/interface always indicate a violation of the single responsibility principle. Maybe the file/class/object/interface wants to manage too many things at once. Extract functionality which clearly belongs together.

[Documentation](https://detekt.dev/docs/rules/complexity#toomanyfunctions)

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/service/PostService.kt:43:7
```
Class 'PostServiceImpl' with '12' functions detected. Defined threshold inside classes is set to '11'
```
```kotlin
40  * - Coroutines async/awaitのナビゲーション
41  * - context receivers使用時の型解決
42  */
43 class PostServiceImpl(
!!       ^ error
44     private val postRepository: PostRepository,
45     private val userRepository: UserRepository
46 ) : PostService {

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/util/Extensions.kt:1:1
```
File '/home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/util/Extensions.kt' with '13' functions detected. Defined threshold inside files is set to '11'
```
```kotlin
1 package com.example.util
! ^ error
2 
3 import arrow.core.Either
4 import arrow.core.raise.either

```

### exceptions, TooGenericExceptionCaught (1)

The caught exception is too generic. Prefer catching specific exceptions to the case that is currently handled.

[Documentation](https://detekt.dev/docs/rules/exceptions#toogenericexceptioncaught)

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/util/Extensions.kt:95:18
```
The caught exception is too generic. Prefer catching specific exceptions to the case that is currently handled.
```
```kotlin
92     repeat(times - 1) { attempt ->
93         try {
94             return block()
95         } catch (e: Exception) {
!!                  ^ error
96             println("Attempt ${attempt + 1} failed: ${e.message}")
97             kotlinx.coroutines.delay(delayMillis)
98         }

```

### formatting, ImportOrdering (1)

Detects imports in non default order

[Documentation](https://detekt.dev/docs/rules/formatting#importordering)

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/service/UserService.kt:3:1
```
Imports must be ordered in lexicographic order without any empty lines in-between with "java", "javax", "kotlin" and aliases in the end
```
```kotlin
1 package com.example.service
2 
3 import arrow.core.Either
! ^ error
4 import arrow.core.raise.either
5 import arrow.core.raise.ensure
6 import com.example.domain.*

```

### formatting, Indentation (3)

Reports mis-indented code

[Documentation](https://detekt.dev/docs/rules/formatting#indentation)

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/service/UserService.kt:56:1
```
Unexpected indentation (16) (should be 12)
```
```kotlin
53                 logger.info { "User found: ${user.email}" }
54                 user
55             } ?: run {
56                 logger.warn { "User not found: $id" }
!! ^ error
57                 raise(ServiceError.NotFound("User not found: $id"))
58             }
59     }

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/service/UserService.kt:57:1
```
Unexpected indentation (16) (should be 12)
```
```kotlin
54                 user
55             } ?: run {
56                 logger.warn { "User not found: $id" }
57                 raise(ServiceError.NotFound("User not found: $id"))
!! ^ error
58             }
59     }
60 

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/service/UserService.kt:58:1
```
Unexpected indentation (12) (should be 8)
```
```kotlin
55             } ?: run {
56                 logger.warn { "User not found: $id" }
57                 raise(ServiceError.NotFound("User not found: $id"))
58             }
!! ^ error
59     }
60 
61     override suspend fun getUserByEmail(email: Email): Either<ServiceError, User> = either {

```

### formatting, MaximumLineLength (1)

Reports lines with exceeded length

[Documentation](https://detekt.dev/docs/rules/formatting#maximumlinelength)

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/test/kotlin/com/example/service/UserServiceTest.kt:149:1
```
Exceeded max line length (120)
```
```kotlin
146 
147                 // Then
148                 result.shouldBeLeft()
149                 result.leftOrNull() shouldBe ServiceError.AlreadyExists("User with email existing@example.com already exists")
!!! ^ error
150             }
151         }
152     }

```

### formatting, MultiLineIfElse (2)

Detects multiline if-else statements without braces

[Documentation](https://detekt.dev/docs/rules/formatting#multilineifelse)

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/domain/Post.kt:71:40
```
Missing { ... }
```
```kotlin
68     }
69 
70     fun preview(maxLength: Int = 100): String =
71         if (value.length <= maxLength) value
!!                                        ^ error
72         else value.take(maxLength) + "..."
73 }
74 

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/domain/Post.kt:72:14
```
Missing { ... }
```
```kotlin
69 
70     fun preview(maxLength: Int = 100): String =
71         if (value.length <= maxLength) value
72         else value.take(maxLength) + "..."
!!              ^ error
73 }
74 
75 /**

```

### formatting, NoWildcardImports (21)

Detects wildcard imports

[Documentation](https://detekt.dev/docs/rules/formatting#nowildcardimports)

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/Application.kt:6:1
```
Wildcard import
```
```kotlin
3  import com.example.api.userRoutes
4  import com.example.config.allModules
5  import com.example.service.UserService
6  import io.ktor.serialization.kotlinx.json.*
!  ^ error
7  import io.ktor.server.application.*
8  import io.ktor.server.engine.*
9  import io.ktor.server.netty.*

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/Application.kt:7:1
```
Wildcard import
```
```kotlin
4  import com.example.config.allModules
5  import com.example.service.UserService
6  import io.ktor.serialization.kotlinx.json.*
7  import io.ktor.server.application.*
!  ^ error
8  import io.ktor.server.engine.*
9  import io.ktor.server.netty.*
10 import io.ktor.server.plugins.contentnegotiation.*

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/Application.kt:8:1
```
Wildcard import
```
```kotlin
5  import com.example.service.UserService
6  import io.ktor.serialization.kotlinx.json.*
7  import io.ktor.server.application.*
8  import io.ktor.server.engine.*
!  ^ error
9  import io.ktor.server.netty.*
10 import io.ktor.server.plugins.contentnegotiation.*
11 import io.ktor.server.response.*

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/Application.kt:9:1
```
Wildcard import
```
```kotlin
6  import io.ktor.serialization.kotlinx.json.*
7  import io.ktor.server.application.*
8  import io.ktor.server.engine.*
9  import io.ktor.server.netty.*
!  ^ error
10 import io.ktor.server.plugins.contentnegotiation.*
11 import io.ktor.server.response.*
12 import io.ktor.server.routing.*

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/Application.kt:10:1
```
Wildcard import
```
```kotlin
7  import io.ktor.server.application.*
8  import io.ktor.server.engine.*
9  import io.ktor.server.netty.*
10 import io.ktor.server.plugins.contentnegotiation.*
!! ^ error
11 import io.ktor.server.response.*
12 import io.ktor.server.routing.*
13 import kotlinx.serialization.json.Json

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/Application.kt:11:1
```
Wildcard import
```
```kotlin
8  import io.ktor.server.engine.*
9  import io.ktor.server.netty.*
10 import io.ktor.server.plugins.contentnegotiation.*
11 import io.ktor.server.response.*
!! ^ error
12 import io.ktor.server.routing.*
13 import kotlinx.serialization.json.Json
14 import mu.KotlinLogging

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/Application.kt:12:1
```
Wildcard import
```
```kotlin
9  import io.ktor.server.netty.*
10 import io.ktor.server.plugins.contentnegotiation.*
11 import io.ktor.server.response.*
12 import io.ktor.server.routing.*
!! ^ error
13 import kotlinx.serialization.json.Json
14 import mu.KotlinLogging
15 import org.koin.ktor.ext.inject

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/api/UserRoutes.kt:8:1
```
Wildcard import
```
```kotlin
5  import com.example.domain.UserRole
6  import com.example.service.ServiceError
7  import com.example.service.UserService
8  import io.ktor.http.*
!  ^ error
9  import io.ktor.server.application.*
10 import io.ktor.server.request.*
11 import io.ktor.server.response.*

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/api/UserRoutes.kt:9:1
```
Wildcard import
```
```kotlin
6  import com.example.service.ServiceError
7  import com.example.service.UserService
8  import io.ktor.http.*
9  import io.ktor.server.application.*
!  ^ error
10 import io.ktor.server.request.*
11 import io.ktor.server.response.*
12 import io.ktor.server.routing.*

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/api/UserRoutes.kt:10:1
```
Wildcard import
```
```kotlin
7  import com.example.service.UserService
8  import io.ktor.http.*
9  import io.ktor.server.application.*
10 import io.ktor.server.request.*
!! ^ error
11 import io.ktor.server.response.*
12 import io.ktor.server.routing.*
13 import kotlinx.serialization.Serializable

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/api/UserRoutes.kt:11:1
```
Wildcard import
```
```kotlin
8  import io.ktor.http.*
9  import io.ktor.server.application.*
10 import io.ktor.server.request.*
11 import io.ktor.server.response.*
!! ^ error
12 import io.ktor.server.routing.*
13 import kotlinx.serialization.Serializable
14 

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/api/UserRoutes.kt:12:1
```
Wildcard import
```
```kotlin
9  import io.ktor.server.application.*
10 import io.ktor.server.request.*
11 import io.ktor.server.response.*
12 import io.ktor.server.routing.*
!! ^ error
13 import kotlinx.serialization.Serializable
14 
15 /**

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/config/DIContainer.kt:3:1
```
Wildcard import
```
```kotlin
1 package com.example.config
2 
3 import com.example.repository.*
! ^ error
4 import com.example.service.*
5 import org.koin.core.module.dsl.bind
6 import org.koin.core.module.dsl.singleOf

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/config/DIContainer.kt:4:1
```
Wildcard import
```
```kotlin
1 package com.example.config
2 
3 import com.example.repository.*
4 import com.example.service.*
! ^ error
5 import org.koin.core.module.dsl.bind
6 import org.koin.core.module.dsl.singleOf
7 import org.koin.dsl.module

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/repository/PostRepository.kt:4:1
```
Wildcard import
```
```kotlin
1 package com.example.repository
2 
3 import arrow.core.Either
4 import com.example.domain.*
! ^ error
5 import org.jetbrains.exposed.dao.id.LongIdTable
6 import org.jetbrains.exposed.sql.*
7 import org.jetbrains.exposed.sql.SqlExpressionBuilder.eq

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/repository/PostRepository.kt:6:1
```
Wildcard import
```
```kotlin
3  import arrow.core.Either
4  import com.example.domain.*
5  import org.jetbrains.exposed.dao.id.LongIdTable
6  import org.jetbrains.exposed.sql.*
!  ^ error
7  import org.jetbrains.exposed.sql.SqlExpressionBuilder.eq
8  import org.jetbrains.exposed.sql.javatime.datetime
9  import org.jetbrains.exposed.sql.transactions.transaction

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/repository/UserRepository.kt:4:1
```
Wildcard import
```
```kotlin
1 package com.example.repository
2 
3 import arrow.core.Either
4 import com.example.domain.*
! ^ error
5 import org.jetbrains.exposed.dao.id.LongIdTable
6 import org.jetbrains.exposed.sql.*
7 import org.jetbrains.exposed.sql.SqlExpressionBuilder.eq

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/repository/UserRepository.kt:6:1
```
Wildcard import
```
```kotlin
3  import arrow.core.Either
4  import com.example.domain.*
5  import org.jetbrains.exposed.dao.id.LongIdTable
6  import org.jetbrains.exposed.sql.*
!  ^ error
7  import org.jetbrains.exposed.sql.SqlExpressionBuilder.eq
8  import org.jetbrains.exposed.sql.javatime.datetime
9  import org.jetbrains.exposed.sql.transactions.transaction

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/service/PostService.kt:6:1
```
Wildcard import
```
```kotlin
3  import arrow.core.Either
4  import arrow.core.raise.either
5  import arrow.core.raise.ensure
6  import com.example.domain.*
!  ^ error
7  import com.example.repository.PostRepository
8  import com.example.repository.UserRepository
9  import kotlinx.coroutines.async

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/service/UserService.kt:6:1
```
Wildcard import
```
```kotlin
3  import arrow.core.Either
4  import arrow.core.raise.either
5  import arrow.core.raise.ensure
6  import com.example.domain.*
!  ^ error
7  import com.example.repository.UserRepository
8  import com.example.repository.RepositoryError
9  import kotlinx.coroutines.Dispatchers

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/test/kotlin/com/example/service/UserServiceTest.kt:4:1
```
Wildcard import
```
```kotlin
1 package com.example.service
2 
3 import arrow.core.Either
4 import com.example.domain.*
! ^ error
5 import com.example.repository.RepositoryError
6 import com.example.repository.UserRepository
7 import io.kotest.assertions.arrow.core.shouldBeLeft

```

### formatting, Wrapping (2)

Reports missing newlines (e.g. between parentheses of a multi-line function call

[Documentation](https://detekt.dev/docs/rules/formatting#wrapping)

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/Application.kt:50:14
```
Missing newline after "("
```
```kotlin
47 
48     // JSON シリアライゼーション設定
49     install(ContentNegotiation) {
50         json(Json {
!!              ^ error
51             prettyPrint = true
52             isLenient = true
53             ignoreUnknownKeys = true

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/Application.kt:54:9
```
Missing newline before ")"
```
```kotlin
51             prettyPrint = true
52             isLenient = true
53             ignoreUnknownKeys = true
54         })
!!         ^ error
55     }
56 
57     // ルーティング設定

```

### style, MaxLineLength (1)

Line detected, which is longer than the defined maximum line length in the code style.

[Documentation](https://detekt.dev/docs/rules/style#maxlinelength)

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/test/kotlin/com/example/service/UserServiceTest.kt:149:1
```
Line detected, which is longer than the defined maximum line length in the code style.
```
```kotlin
146 
147                 // Then
148                 result.shouldBeLeft()
149                 result.leftOrNull() shouldBe ServiceError.AlreadyExists("User with email existing@example.com already exists")
!!! ^ error
150             }
151         }
152     }

```

### style, WildcardImport (21)

Wildcard imports should be replaced with imports using fully qualified class names. Wildcard imports can lead to naming conflicts. A library update can introduce naming clashes with your classes which results in compilation errors.

[Documentation](https://detekt.dev/docs/rules/style#wildcardimport)

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/Application.kt:6:1
```
io.ktor.serialization.kotlinx.json.* is a wildcard import. Replace it with fully qualified imports.
```
```kotlin
3  import com.example.api.userRoutes
4  import com.example.config.allModules
5  import com.example.service.UserService
6  import io.ktor.serialization.kotlinx.json.*
!  ^ error
7  import io.ktor.server.application.*
8  import io.ktor.server.engine.*
9  import io.ktor.server.netty.*

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/Application.kt:7:1
```
io.ktor.server.application.* is a wildcard import. Replace it with fully qualified imports.
```
```kotlin
4  import com.example.config.allModules
5  import com.example.service.UserService
6  import io.ktor.serialization.kotlinx.json.*
7  import io.ktor.server.application.*
!  ^ error
8  import io.ktor.server.engine.*
9  import io.ktor.server.netty.*
10 import io.ktor.server.plugins.contentnegotiation.*

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/Application.kt:8:1
```
io.ktor.server.engine.* is a wildcard import. Replace it with fully qualified imports.
```
```kotlin
5  import com.example.service.UserService
6  import io.ktor.serialization.kotlinx.json.*
7  import io.ktor.server.application.*
8  import io.ktor.server.engine.*
!  ^ error
9  import io.ktor.server.netty.*
10 import io.ktor.server.plugins.contentnegotiation.*
11 import io.ktor.server.response.*

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/Application.kt:9:1
```
io.ktor.server.netty.* is a wildcard import. Replace it with fully qualified imports.
```
```kotlin
6  import io.ktor.serialization.kotlinx.json.*
7  import io.ktor.server.application.*
8  import io.ktor.server.engine.*
9  import io.ktor.server.netty.*
!  ^ error
10 import io.ktor.server.plugins.contentnegotiation.*
11 import io.ktor.server.response.*
12 import io.ktor.server.routing.*

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/Application.kt:10:1
```
io.ktor.server.plugins.contentnegotiation.* is a wildcard import. Replace it with fully qualified imports.
```
```kotlin
7  import io.ktor.server.application.*
8  import io.ktor.server.engine.*
9  import io.ktor.server.netty.*
10 import io.ktor.server.plugins.contentnegotiation.*
!! ^ error
11 import io.ktor.server.response.*
12 import io.ktor.server.routing.*
13 import kotlinx.serialization.json.Json

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/Application.kt:11:1
```
io.ktor.server.response.* is a wildcard import. Replace it with fully qualified imports.
```
```kotlin
8  import io.ktor.server.engine.*
9  import io.ktor.server.netty.*
10 import io.ktor.server.plugins.contentnegotiation.*
11 import io.ktor.server.response.*
!! ^ error
12 import io.ktor.server.routing.*
13 import kotlinx.serialization.json.Json
14 import mu.KotlinLogging

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/Application.kt:12:1
```
io.ktor.server.routing.* is a wildcard import. Replace it with fully qualified imports.
```
```kotlin
9  import io.ktor.server.netty.*
10 import io.ktor.server.plugins.contentnegotiation.*
11 import io.ktor.server.response.*
12 import io.ktor.server.routing.*
!! ^ error
13 import kotlinx.serialization.json.Json
14 import mu.KotlinLogging
15 import org.koin.ktor.ext.inject

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/api/UserRoutes.kt:8:1
```
io.ktor.http.* is a wildcard import. Replace it with fully qualified imports.
```
```kotlin
5  import com.example.domain.UserRole
6  import com.example.service.ServiceError
7  import com.example.service.UserService
8  import io.ktor.http.*
!  ^ error
9  import io.ktor.server.application.*
10 import io.ktor.server.request.*
11 import io.ktor.server.response.*

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/api/UserRoutes.kt:9:1
```
io.ktor.server.application.* is a wildcard import. Replace it with fully qualified imports.
```
```kotlin
6  import com.example.service.ServiceError
7  import com.example.service.UserService
8  import io.ktor.http.*
9  import io.ktor.server.application.*
!  ^ error
10 import io.ktor.server.request.*
11 import io.ktor.server.response.*
12 import io.ktor.server.routing.*

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/api/UserRoutes.kt:10:1
```
io.ktor.server.request.* is a wildcard import. Replace it with fully qualified imports.
```
```kotlin
7  import com.example.service.UserService
8  import io.ktor.http.*
9  import io.ktor.server.application.*
10 import io.ktor.server.request.*
!! ^ error
11 import io.ktor.server.response.*
12 import io.ktor.server.routing.*
13 import kotlinx.serialization.Serializable

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/api/UserRoutes.kt:11:1
```
io.ktor.server.response.* is a wildcard import. Replace it with fully qualified imports.
```
```kotlin
8  import io.ktor.http.*
9  import io.ktor.server.application.*
10 import io.ktor.server.request.*
11 import io.ktor.server.response.*
!! ^ error
12 import io.ktor.server.routing.*
13 import kotlinx.serialization.Serializable
14 

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/api/UserRoutes.kt:12:1
```
io.ktor.server.routing.* is a wildcard import. Replace it with fully qualified imports.
```
```kotlin
9  import io.ktor.server.application.*
10 import io.ktor.server.request.*
11 import io.ktor.server.response.*
12 import io.ktor.server.routing.*
!! ^ error
13 import kotlinx.serialization.Serializable
14 
15 /**

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/config/DIContainer.kt:3:1
```
com.example.repository.* is a wildcard import. Replace it with fully qualified imports.
```
```kotlin
1 package com.example.config
2 
3 import com.example.repository.*
! ^ error
4 import com.example.service.*
5 import org.koin.core.module.dsl.bind
6 import org.koin.core.module.dsl.singleOf

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/config/DIContainer.kt:4:1
```
com.example.service.* is a wildcard import. Replace it with fully qualified imports.
```
```kotlin
1 package com.example.config
2 
3 import com.example.repository.*
4 import com.example.service.*
! ^ error
5 import org.koin.core.module.dsl.bind
6 import org.koin.core.module.dsl.singleOf
7 import org.koin.dsl.module

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/repository/PostRepository.kt:4:1
```
com.example.domain.* is a wildcard import. Replace it with fully qualified imports.
```
```kotlin
1 package com.example.repository
2 
3 import arrow.core.Either
4 import com.example.domain.*
! ^ error
5 import org.jetbrains.exposed.dao.id.LongIdTable
6 import org.jetbrains.exposed.sql.*
7 import org.jetbrains.exposed.sql.SqlExpressionBuilder.eq

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/repository/PostRepository.kt:6:1
```
org.jetbrains.exposed.sql.* is a wildcard import. Replace it with fully qualified imports.
```
```kotlin
3  import arrow.core.Either
4  import com.example.domain.*
5  import org.jetbrains.exposed.dao.id.LongIdTable
6  import org.jetbrains.exposed.sql.*
!  ^ error
7  import org.jetbrains.exposed.sql.SqlExpressionBuilder.eq
8  import org.jetbrains.exposed.sql.javatime.datetime
9  import org.jetbrains.exposed.sql.transactions.transaction

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/repository/UserRepository.kt:4:1
```
com.example.domain.* is a wildcard import. Replace it with fully qualified imports.
```
```kotlin
1 package com.example.repository
2 
3 import arrow.core.Either
4 import com.example.domain.*
! ^ error
5 import org.jetbrains.exposed.dao.id.LongIdTable
6 import org.jetbrains.exposed.sql.*
7 import org.jetbrains.exposed.sql.SqlExpressionBuilder.eq

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/repository/UserRepository.kt:6:1
```
org.jetbrains.exposed.sql.* is a wildcard import. Replace it with fully qualified imports.
```
```kotlin
3  import arrow.core.Either
4  import com.example.domain.*
5  import org.jetbrains.exposed.dao.id.LongIdTable
6  import org.jetbrains.exposed.sql.*
!  ^ error
7  import org.jetbrains.exposed.sql.SqlExpressionBuilder.eq
8  import org.jetbrains.exposed.sql.javatime.datetime
9  import org.jetbrains.exposed.sql.transactions.transaction

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/service/PostService.kt:6:1
```
com.example.domain.* is a wildcard import. Replace it with fully qualified imports.
```
```kotlin
3  import arrow.core.Either
4  import arrow.core.raise.either
5  import arrow.core.raise.ensure
6  import com.example.domain.*
!  ^ error
7  import com.example.repository.PostRepository
8  import com.example.repository.UserRepository
9  import kotlinx.coroutines.async

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/main/kotlin/com/example/service/UserService.kt:6:1
```
com.example.domain.* is a wildcard import. Replace it with fully qualified imports.
```
```kotlin
3  import arrow.core.Either
4  import arrow.core.raise.either
5  import arrow.core.raise.ensure
6  import com.example.domain.*
!  ^ error
7  import com.example.repository.UserRepository
8  import com.example.repository.RepositoryError
9  import kotlinx.coroutines.Dispatchers

```

* /home/glaucus03/dev/projects/kotlin-extended-lsp.nvim/test-project/src/test/kotlin/com/example/service/UserServiceTest.kt:4:1
```
com.example.domain.* is a wildcard import. Replace it with fully qualified imports.
```
```kotlin
1 package com.example.service
2 
3 import arrow.core.Either
4 import com.example.domain.*
! ^ error
5 import com.example.repository.RepositoryError
6 import com.example.repository.UserRepository
7 import io.kotest.assertions.arrow.core.shouldBeLeft

```

generated with [detekt version 1.23.8](https://detekt.dev/) on 2025-11-10 11:14:45 UTC
