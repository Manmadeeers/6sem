using Ocelot.LoadBalancer.Interfaces;
using Ocelot.Responses;
using Ocelot.Values;

namespace OcelotGateway.LoadBalancing;

public sealed class CustomWeightedLoadBalancer : ILoadBalancer
{
    private static readonly double[] Weights = [0.5, 0.3, 0.2];
    private static readonly double TotalWeight = Weights.Sum();
    private readonly Func<Task<List<Service>>> _servicesFactory;

    public CustomWeightedLoadBalancer(Func<Task<List<Service>>> servicesFactory)
    {
        _servicesFactory = servicesFactory;
    }

    public string Type => nameof(CustomWeightedLoadBalancer);

    public async Task<Response<ServiceHostAndPort>> LeaseAsync(HttpContext httpContext)
    {
        var services = await _servicesFactory();

        if (services.Count != Weights.Length)
        {
            throw new InvalidOperationException($"Expected {Weights.Length} downstream services but got {services.Count}.");
        }

        var randomValue = Random.Shared.NextDouble() * TotalWeight;
        var cumulative = 0.0;

        for (var index = 0; index < services.Count; index++)
        {
            cumulative += Weights[index];

            if (randomValue <= cumulative)
            {
                return new OkResponse<ServiceHostAndPort>(services[index].HostAndPort);
            }
        }

        return new OkResponse<ServiceHostAndPort>(services[^1].HostAndPort);
    }

    public void Release(ServiceHostAndPort hostAndPort)
    {
    }
}
