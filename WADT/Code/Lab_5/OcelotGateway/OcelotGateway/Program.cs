using Ocelot.Middleware;
using Ocelot.DependencyInjection;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddOcelot();

builder.Configuration.AddJsonFile("ocelot_custom.json", optional: false, reloadOnChange: true);

builder.Services
   .AddOcelot(builder.Configuration)
   .AddCustomLoadBalancer<OcelotGateway.LoadBalancing.CustomWeightedLoadBalancer>((_, serviceDiscoveryProvider) =>
       new OcelotGateway.LoadBalancing.CustomWeightedLoadBalancer(() => serviceDiscoveryProvider.GetAsync()));

//builder.Configuration.AddJsonFile("ocelot.json", optional: false, reloadOnChange: true);

//builder.Configuration.AddJsonFile("ocelot_sticky.json", optional: false, reloadOnChange: true);



var app = builder.Build();

await app.UseOcelot();

app.Run();
