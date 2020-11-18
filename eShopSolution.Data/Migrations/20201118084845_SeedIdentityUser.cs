using System;
using Microsoft.EntityFrameworkCore.Migrations;

namespace eShopSolution.Data.Migrations
{
    public partial class SeedIdentityUser : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<DateTime>(
                name: "OrderDate",
                table: "Orders",
                nullable: false,
                defaultValue: new DateTime(2020, 11, 18, 15, 48, 44, 297, DateTimeKind.Local).AddTicks(6221),
                oldClrType: typeof(DateTime),
                oldType: "datetime2",
                oldDefaultValue: new DateTime(2020, 11, 18, 15, 37, 8, 186, DateTimeKind.Local).AddTicks(5319));

            migrationBuilder.InsertData(
                table: "AppRoles",
                columns: new[] { "Id", "ConcurrencyStamp", "Description", "Name", "NormalizedName" },
                values: new object[] { new Guid("b6dd242d-77bc-4b81-90ef-08970eddd6d7"), "159cbec6-53f1-4677-b539-b7a971975971", "Administrator role", "admin", "admin" });

            migrationBuilder.InsertData(
                table: "AppUserRoles",
                columns: new[] { "UserId", "RoleId" },
                values: new object[] { new Guid("be0ad16a-1ba1-4f37-a5a1-080f950c581a"), new Guid("b6dd242d-77bc-4b81-90ef-08970eddd6d7") });

            migrationBuilder.InsertData(
                table: "AppUsers",
                columns: new[] { "Id", "AccessFailedCount", "ConcurrencyStamp", "Dob", "Email", "EmailConfirmed", "FirstName", "LastName", "LockoutEnabled", "LockoutEnd", "NormalizedEmail", "NormalizedUserName", "PasswordHash", "PhoneNumber", "PhoneNumberConfirmed", "SecurityStamp", "TwoFactorEnabled", "UserName" },
                values: new object[] { new Guid("be0ad16a-1ba1-4f37-a5a1-080f950c581a"), 0, "0ff2bba2-8042-4b66-adc7-598451b138de", new DateTime(1995, 8, 8, 0, 0, 0, 0, DateTimeKind.Unspecified), "vodongha@hotmail.com", true, "Hà", "Võ Đông", false, null, "vodongha@hotmail.com", "admin", "AQAAAAEAACcQAAAAEL4+3dwy1ZgwJ9Ly5J46a2lIFroRgJ6cjXgAaimosoGVBgslMYiyTUDM6H787OsThQ==", null, false, "", false, "admin" });

            migrationBuilder.UpdateData(
                table: "Categories",
                keyColumn: "Id",
                keyValue: 1,
                column: "Status",
                value: 1);

            migrationBuilder.UpdateData(
                table: "Categories",
                keyColumn: "Id",
                keyValue: 2,
                column: "Status",
                value: 1);

            migrationBuilder.UpdateData(
                table: "Products",
                keyColumn: "Id",
                keyValue: 1,
                column: "DateCreated",
                value: new DateTime(2020, 11, 18, 15, 48, 44, 317, DateTimeKind.Local).AddTicks(9268));
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DeleteData(
                table: "AppRoles",
                keyColumn: "Id",
                keyValue: new Guid("b6dd242d-77bc-4b81-90ef-08970eddd6d7"));

            migrationBuilder.DeleteData(
                table: "AppUserRoles",
                keyColumns: new[] { "UserId", "RoleId" },
                keyValues: new object[] { new Guid("be0ad16a-1ba1-4f37-a5a1-080f950c581a"), new Guid("b6dd242d-77bc-4b81-90ef-08970eddd6d7") });

            migrationBuilder.DeleteData(
                table: "AppUsers",
                keyColumn: "Id",
                keyValue: new Guid("be0ad16a-1ba1-4f37-a5a1-080f950c581a"));

            migrationBuilder.AlterColumn<DateTime>(
                name: "OrderDate",
                table: "Orders",
                type: "datetime2",
                nullable: false,
                defaultValue: new DateTime(2020, 11, 18, 15, 37, 8, 186, DateTimeKind.Local).AddTicks(5319),
                oldClrType: typeof(DateTime),
                oldDefaultValue: new DateTime(2020, 11, 18, 15, 48, 44, 297, DateTimeKind.Local).AddTicks(6221));

            migrationBuilder.UpdateData(
                table: "Categories",
                keyColumn: "Id",
                keyValue: 1,
                column: "Status",
                value: 1);

            migrationBuilder.UpdateData(
                table: "Categories",
                keyColumn: "Id",
                keyValue: 2,
                column: "Status",
                value: 1);

            migrationBuilder.UpdateData(
                table: "Products",
                keyColumn: "Id",
                keyValue: 1,
                column: "DateCreated",
                value: new DateTime(2020, 11, 18, 15, 37, 8, 206, DateTimeKind.Local).AddTicks(1915));
        }
    }
}
