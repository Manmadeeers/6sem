using Ocelot.Middleware;
using Ocelot.DependencyInjection;
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddOcelot();

//builder.Configuration.AddJsonFile("ocelot.json", optional: false, reloadOnChange: true);
builder.Configuration.AddJsonFile("ocelot_sticky.json", optional: false, reloadOnChange: true);

var app = builder.Build();

app.UseOcelot();

app.Run();
