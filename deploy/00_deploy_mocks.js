module.exports = async({
    getNamedAccounts,
    deployments,
    getChainId
}) => {
    const {deploy, log} = deployments
    const {deployer} = await getNamedAccounts()
    const chainId = await getChainId()

    if (chainId == 31337) {
        log("Deploying mocks to local network...")
        const LinkToken = await deploy('LinkToken', {from: deployer, log: true})
        const vrfCoordinator = await deploy('VRFCoordinatorMock', {from: deployer, log: true, args: [LinkToken.address]})
        log("... mocks deployed");
    }
}

module.exports.tags = ['all', 'rsvg', 'svg'];