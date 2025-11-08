package com.example.service

import arrow.core.Either
import com.example.domain.*
import com.example.repository.RepositoryError
import com.example.repository.UserRepository
import io.kotest.assertions.arrow.core.shouldBeLeft
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.core.spec.style.DescribeSpec
import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldContain
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk

/**
 * UserServiceのテスト
 * LSPテスト項目:
 * - テストクラスからプロダクションコードへのジャンプ
 * - MockK DSLの型解決とシグネチャヘルプ
 * - Kotest matchersの補完とナビゲーション
 * - suspend関数のテスト
 */
class UserServiceTest : DescribeSpec({
    // モックリポジトリ
    // LSPテスト: モック関数の型推論
    val userRepository = mockk<UserRepository>()
    val userService = UserServiceImpl(userRepository)

    // テストデータ
    val testUser = User.create(
        email = "test@example.com",
        name = "Test User",
        role = UserRole.USER
    )

    describe("getUserById") {
        context("ユーザーが存在する場合") {
            it("ユーザーを返す") {
                // Given
                coEvery { userRepository.findById(testUser.id) } returns
                    Either.Right(testUser)

                // When
                val result = userService.getUserById(testUser.id)

                // Then
                result shouldBeRight testUser
                coVerify(exactly = 1) { userRepository.findById(testUser.id) }
            }
        }

        context("ユーザーが存在しない場合") {
            it("NotFoundエラーを返す") {
                // Given
                coEvery { userRepository.findById(any()) } returns Either.Right(null)

                // When
                val result = userService.getUserById(UserId(999))

                // Then
                result.shouldBeLeft()
                result.leftOrNull() shouldBe ServiceError.NotFound("User not found: UserId(value=999)")
            }
        }

        context("データベースエラーが発生した場合") {
            it("DatabaseErrorを返す") {
                // Given
                val error = RepositoryError.DatabaseError("Connection failed")
                coEvery { userRepository.findById(any()) } returns Either.Left(error)

                // When
                val result = userService.getUserById(UserId(1))

                // Then
                result.shouldBeLeft()
                (result.leftOrNull() as? ServiceError.DatabaseError)?.message shouldContain "Connection failed"
            }
        }
    }

    describe("createUser") {
        context("有効なデータの場合") {
            it("ユーザーを作成する") {
                // Given
                coEvery { userRepository.existsByEmail(any()) } returns Either.Right(false)
                coEvery { userRepository.save(any()) } returns Either.Right(testUser)

                // When
                val result = userService.createUser(
                    email = "new@example.com",
                    name = "New User",
                    role = UserRole.USER
                )

                // Then
                result.shouldBeRight()
                val createdUser = result.getOrNull()!!
                createdUser.email.value shouldBe "new@example.com"
                createdUser.name.value shouldBe "New User"
            }
        }

        context("無効なメールアドレスの場合") {
            it("ValidationErrorを返す") {
                // When
                val result = userService.createUser(
                    email = "invalid-email",
                    name = "User",
                    role = UserRole.USER
                )

                // Then
                result.shouldBeLeft()
                (result.leftOrNull() as? ServiceError.ValidationError)?.message shouldContain "Invalid email"
            }
        }

        context("空のユーザー名の場合") {
            it("ValidationErrorを返す") {
                // When
                val result = userService.createUser(
                    email = "valid@example.com",
                    name = "",
                    role = UserRole.USER
                )

                // Then
                result.shouldBeLeft()
                (result.leftOrNull() as? ServiceError.ValidationError)?.message shouldContain "Name cannot be blank"
            }
        }

        context("既存のメールアドレスの場合") {
            it("AlreadyExistsエラーを返す") {
                // Given
                coEvery { userRepository.existsByEmail(any()) } returns Either.Right(true)

                // When
                val result = userService.createUser(
                    email = "existing@example.com",
                    name = "User",
                    role = UserRole.USER
                )

                // Then
                result.shouldBeLeft()
                result.leftOrNull() shouldBe ServiceError.AlreadyExists("User with email existing@example.com already exists")
            }
        }
    }

    describe("activateUser") {
        context("非アクティブユーザーの場合") {
            it("ユーザーをアクティベートする") {
                // Given
                val inactiveUser = testUser.copy(status = UserStatus.INACTIVE)
                coEvery { userRepository.findById(testUser.id) } returns Either.Right(inactiveUser)
                coEvery { userRepository.update(any()) } answers {
                    val updated = firstArg<User>()
                    Either.Right(updated)
                }

                // When
                val result = userService.activateUser(testUser.id)

                // Then
                result.shouldBeRight()
                result.getOrNull()?.status shouldBe UserStatus.ACTIVE
            }
        }
    }

    describe("listUsers") {
        context("有効なパラメータの場合") {
            it("ユーザー一覧を返す") {
                // Given
                val users = listOf(testUser)
                coEvery { userRepository.findAll(any(), any()) } returns Either.Right(users)

                // When
                val result = userService.listUsers(limit = 10, offset = 0)

                // Then
                result.shouldBeRight()
                result.getOrNull() shouldBe users
            }
        }

        context("無効なlimitの場合") {
            it("ValidationErrorを返す") {
                // When
                val result = userService.listUsers(limit = 0, offset = 0)

                // Then
                result.shouldBeLeft()
                (result.leftOrNull() as? ServiceError.ValidationError)?.message shouldContain "Limit must be"
            }
        }

        context("負のoffsetの場合") {
            it("ValidationErrorを返す") {
                // When
                val result = userService.listUsers(limit = 10, offset = -1)

                // Then
                result.shouldBeLeft()
                (result.leftOrNull() as? ServiceError.ValidationError)?.message shouldContain "Offset must be"
            }
        }
    }
})
