from pathlib import Path
import cantera as ct


# Simulation parameters
p = ct.one_atm *2 # pressure [Pa]
Tin = 300.0 *5.5  # unburned gas temperature [K]
reactants = 'H2:1.1, O2:1, AR:5'  # premixed gas composition
width = 0.03  # m
loglevel = 1  # amount of diagnostic output (0 to 8)

# Solution object used to compute mixture properties, set to the state of the
# upstream fuel-air mixture
gas = ct.Solution('h2o2.yaml')
gas.TPX = Tin, p, reactants

# Set up flame object
f = ct.FreeFlame(gas, width=width)
f.set_refine_criteria(ratio=3, slope=0.06, curve=0.12)
f.show()

# Solve with mixture-averaged transport model
f.transport_model = 'mixture-averaged'
# Compute diffusive fluxes using a mass fraction-based gradient ("mass")
# or mole fraction-based gradient ("mole", default)
f.flux_gradient_basis = "mass" # only relevant for mixture-averaged model
f.solve(loglevel=loglevel, auto=True)

f.show()
print(f"mixture-averaged flamespeed = {f.velocity[0]:7f} m/s")

# Solve with mixture-averaged transport model and Soret diffusion
f.soret_enabled = True
f.solve(loglevel=loglevel) # don't use 'auto' on subsequent solves

f.show()
print("mixture-averaged flamespeed with Soret diffusion"
      f" = {f.velocity[0]:7f} m/s")

output_dir = Path(__file__).resolve().parent
if "native" in ct.hdf_support():
    output = output_dir / "adiabatic_flame.h5"
else:
    output = output_dir / "adiabatic_flame.yaml"
output.unlink(missing_ok=True)

f.save(output, name="mix", description="solution with mixture-averaged "
                                       "transport and Soret diffusion")

# Solve with multi-component transport properties
# but without Soret diffusion
f.transport_model = 'multicomponent'
f.soret_enabled = False
f.solve(loglevel)
f.show()
print("multicomponent flamespeed without Soret diffusion"
      f" = {f.velocity[0]:7f} m/s")

# Solve with multi-component transport properties and Soret diffusion
f.soret_enabled = True
f.solve(loglevel)
f.show()
print("multicomponent flamespeed with Soret diffusion"
      f" = {f.velocity[0]:7f} m/s")

f.save(output, name="multi", description="solution with multicomponent transport "
                                         "and Soret diffusion")

# write the velocity, temperature, density, and mole fractions to a CSV file
f.save(output_dir / 'adiabatic_flame.csv', basis="mole", overwrite=True)
print('solution saved to', output_dir / 'adiabatic_flame.csv')
print('Pressure:', f.P / ct.one_atm, 'atm')
print('Inlet density:', f.density_mass[0], 'kg/m3')
