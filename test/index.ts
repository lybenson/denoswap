import { expect } from 'chai'
import { ethers } from 'hardhat'

describe('Factory', function () {
  it('Factory contract create pair', async function () {
    const Factory = await ethers.getContractFactory('DenoswapFactory')
    const factory = await Factory.deploy('0x5E3962CA95Cb7BDceF5d55c9EAC80bF2d4F3235E')
    await factory.deployed()

    // expect(await factory.greet()).to.equal('Hello, world!')

    // const setGreetingTx = await greeter.setGreeting('Hola, mundo!')

    // wait until the transaction is mined
    // await setGreetingTx.wait()

    // expect(await greeter.greet()).to.equal('Hola, mundo!')
  })
})
