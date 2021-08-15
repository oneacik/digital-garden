![Avocado](../assets/avocado.png)

## Rationale

Have you ever felt that your function has a lot of load  
not exactly contributing to the core functionality?  
Caching, Logging, Assertions, Exception Handling -  
are some layers that fog the core functionality.  
Avocado Object principle tends to declutter core functionality,  
putting supporting features in different layers.  

## What is Avocado Object?

Avocado Object has its seed as implementation of core functionality.  
The pulp are decorators of all kinds layering around the seed.  
The peel is a metaphor for common interface that all of them implement.  

Avocado can be constructed by a factory method or a factory.  
Preferably in a container framework or by a factory method on interface.

Avocado Objects call each other, usually from the seed or  
in exceptional cases - from the other layers.  

## Advantages and Disadvantages of AOs

### Advantages

- Core functionality is more visible
- Code is more flexible
- Layering approach allows enforcing different laws for each layer (refer to ArchUnit and LayerSuperType)
- Clean Code/Architecture is enforced by decorator boundaries
- Self Similarity if enforced globally

### Disadvantages

- Factory Methods/Factories are needed
- Design becomes more complex

## Example

TBD