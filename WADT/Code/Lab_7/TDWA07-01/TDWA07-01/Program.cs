using Microsoft.Data.SqlClient;

var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

string connectionString =
    Environment.GetEnvironmentVariable("CONNECTION_STRING")
    ?? "Server=host.docker.internal,1444;Database=Celebrities;User Id=sa;Password=!StrongPass123;Encrypt=True;TrustServerCertificate=True;";

app.MapGet("/db", async () =>
{
    await using var conn = new SqlConnection(connectionString);
    await conn.OpenAsync();

    var cmd = new SqlCommand("SELECT Id, FullName, Nationality, ReqPhotoPath FROM Celebrities", conn);
    await using var rdr = await cmd.ExecuteReaderAsync();

    var result = new List<Celebrity>();
    while (await rdr.ReadAsync())
    {
        result.Add(new Celebrity(
            Id: rdr.GetInt32(0),
            FullName: rdr.IsDBNull(1) ? "" : rdr.GetString(1),
            Nationality: rdr.IsDBNull(2) ? "" : rdr.GetString(2),
            ReqPhotoPath: rdr.IsDBNull(3) ? "" : rdr.GetString(3)
        ));
    }

    return result.Count == 0 ? Results.NoContent() : Results.Ok(result);
});

app.MapGet("/db/{id:int}", async (int id) =>
{
    await using var conn = new SqlConnection(connectionString);
    await conn.OpenAsync();

    var cmd = new SqlCommand(
        "SELECT Id, FullName, Nationality, ReqPhotoPath FROM Celebrities WHERE Id=@Id",
        conn);
    cmd.Parameters.AddWithValue("@Id", id);

    await using var rdr = await cmd.ExecuteReaderAsync();
    if (!await rdr.ReadAsync())
        return Results.NotFound(new { error = "Record not found" });

    var row = new Celebrity(
        Id: rdr.GetInt32(0),
        FullName: rdr.IsDBNull(1) ? "" : rdr.GetString(1),
        Nationality: rdr.IsDBNull(2) ? "" : rdr.GetString(2),
        ReqPhotoPath: rdr.IsDBNull(3) ? "" : rdr.GetString(3)
    );

    return Results.Ok(row);
});

app.MapPost("/db", async (CelebrityCreateUpdate body) =>
{
    await using var conn = new SqlConnection(connectionString);
    await conn.OpenAsync();

    var cmd = new SqlCommand(
        @"INSERT INTO Celebrities (FullName, Nationality, ReqPhotoPath)
          OUTPUT INSERTED.Id
          VALUES (@FullName, @Nationality, @ReqPhotoPath)",
        conn);

    cmd.Parameters.AddWithValue("@FullName", body.FullName ?? (object)DBNull.Value);
    cmd.Parameters.AddWithValue("@Nationality", body.Nationality ?? (object)DBNull.Value);
    cmd.Parameters.AddWithValue("@ReqPhotoPath", body.ReqPhotoPath ?? (object)DBNull.Value);

    var newId = (int)(await cmd.ExecuteScalarAsync() ?? 0);

    return Results.Created($"/db/{newId}", new
    {
        Id = newId,
        body.FullName,
        body.Nationality,
        body.ReqPhotoPath
    });
});

app.MapPut("/db/{id:int}", async (int id, CelebrityCreateUpdate body) =>
{
    await using var conn = new SqlConnection(connectionString);
    await conn.OpenAsync();

    var cmd = new SqlCommand(
        @"UPDATE Celebrities
          SET FullName=@FullName, Nationality=@Nationality, ReqPhotoPath=@ReqPhotoPath
          WHERE Id=@Id",
        conn);

    cmd.Parameters.AddWithValue("@Id", id);
    cmd.Parameters.AddWithValue("@FullName", body.FullName ?? (object)DBNull.Value);
    cmd.Parameters.AddWithValue("@Nationality", body.Nationality ?? (object)DBNull.Value);
    cmd.Parameters.AddWithValue("@ReqPhotoPath", body.ReqPhotoPath ?? (object)DBNull.Value);

    var affected = await cmd.ExecuteNonQueryAsync();
    if (affected == 0)
        return Results.NotFound(new { error = "Record not found" });

    return Results.Ok(new
    {
        Id = id,
        body.FullName,
        body.Nationality,
        body.ReqPhotoPath
    });
});

app.MapDelete("/db/{id:int}", async (int id) =>
{
    await using var conn = new SqlConnection(connectionString);
    await conn.OpenAsync();

    var cmd = new SqlCommand("DELETE FROM Celebrities WHERE Id=@Id", conn);
    cmd.Parameters.AddWithValue("@Id", id);

    var affected = await cmd.ExecuteNonQueryAsync();
    if (affected == 0)
        return Results.NotFound(new { error = "Record not found" });

    return Results.Ok(new { success = $"Element with id {id} successfully deleted" });
});

// Startup DB check (like your initDB)
await CheckDatabaseAsync(connectionString);

app.Run("http://0.0.0.0:3000");

static async Task CheckDatabaseAsync(string connStr)
{
    try
    {
        await using var conn = new SqlConnection(connStr);
        await conn.OpenAsync();

        var cmd = new SqlCommand("SELECT name FROM sys.databases WHERE name = 'Celebrities'", conn);
        var dbName = (string?)await cmd.ExecuteScalarAsync();

        Console.WriteLine(dbName is null
            ? "Database check result: Celebrities not found"
            : $"Database check result: {dbName} found");
    }
    catch (Exception ex)
    {
        Console.WriteLine($"Database init error: {ex.Message}");
    }
}

public record Celebrity(int Id, string FullName, string Nationality, string ReqPhotoPath);
public record CelebrityCreateUpdate(string? FullName, string? Nationality, string? ReqPhotoPath);
